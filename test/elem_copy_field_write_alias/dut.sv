// A FIELD write to an unpacked-array element that was COPIED from another
// array must not reach the SOURCE element.
//
// `extract_assigned_signals` registered `ctrl_mod[11]` twice, inconsistently:
//
//  1. the loop `for (c) ctrl_mod[c] = ctrl_mul[c % NMul];` — at scan time the
//     loop variable is not yet substituted, so the index looks dynamic and the
//     vpiBitSelect branch takes the "Skipping dynamic write to expanded array"
//     early exit and registers NOTHING.  The write is later emitted straight
//     onto `\ctrl_mod[11]`.
//  2. `ctrl_mod[NMod-1].acc_clear_en = 1'b1` — a hier_path with a constant
//     leading bit_select, registered as PARTIAL, which allocated
//     `$0\ctrl_mod[11][0:0]` plus a sync update of that one bit.
//
// One wire, two drivers.  `proc` reconciles them by ALIASING, and because the
// per-element wires are slice aliases of the flat array
// (`connect \ctrl_mul[2] \ctrl_mul [17:12]`) the bit leaked backwards into the
// source: `ctrl_mul[2]` read 6'h17 instead of 6'h16.
//
// 11 % 3 == 2, so ctrl_mod[11] is the copy of ctrl_mul[2] — that is the pair
// that aliases.  read_slang keeps them distinct.
//
// OTBN otbn_mac_bignum_fsm's contrl_mod_mul[2] / contrl_mod[LatencyMod-1] is
// the shape in the wild; it drove contrl_o.acc_clear_en wrong from cycle 63
// and, through predec_o/contrl_o, otbn_mac_bignum as well.
module elem_copy_field_write_alias
  (input  logic [1:0] sel_i,
   output logic [5:0] a2_o,
   output logic [5:0] b11_o,
   output logic [5:0] b10_o);
  typedef struct packed {
    logic tmp_wr_en_raw;
    logic tmp_clear_en;
    logic c_wr_en_raw;
    logic c_clear_en;
    logic acc_wr_en_raw;
    logic acc_clear_en;
  } ctrl_t;

  localparam ctrl_t CtrlDefault = '0;
  localparam int unsigned NMul = 3;
  localparam int unsigned NMod = 12;

  ctrl_t ctrl_mul [NMul];
  ctrl_t ctrl_mod [NMod];

  always_comb begin
    ctrl_mul = '{default: CtrlDefault};

    ctrl_mul[0].tmp_wr_en_raw = 1'b1;
    ctrl_mul[0].c_wr_en_raw   = 1'b1;
    ctrl_mul[1].tmp_wr_en_raw = 1'b1;
    ctrl_mul[2].acc_wr_en_raw = 1'b1;
    ctrl_mul[2].tmp_clear_en  = 1'b1;
    ctrl_mul[2].c_clear_en    = 1'b1;

    for (int unsigned cycle = 0; cycle < NMod; cycle++) begin
      ctrl_mod[cycle] = ctrl_mul[cycle % NMul];
    end

    // The field write must land ONLY on element 11.
    ctrl_mod[NMod - 1].acc_clear_en = 1'b1;
  end

  assign a2_o  = ctrl_mul[2];    // must stay 6'h16
  assign b11_o = ctrl_mod[11];   // must be 6'h17
  // Element 10 is a copy of ctrl_mul[1] and must be untouched, so a fix that
  // over-broadly widens the write is caught too.
  assign b10_o = ctrl_mod[10];
endmodule
