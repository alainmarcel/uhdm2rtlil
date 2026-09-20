// Per-field writes into the ELEMENTS of a 1-D unpacked array of structs were
// dropped when the array was ALSO written as a whole and its element struct
// carried an ENUM member:
//
//     d_t v[4];
//     v = '{default: Def};                  // whole-array write
//     for (c...) v[c].qw = idx[c];          // per-element FIELD writes
//
// Every field write resolved to ELEMENT 0's offsets -- `v[0].qw`, `v[1].qw`,
// `v[2].qw` and `v[3].qw` all mapped to `[8 +: 2]` -- so they collided and
// none reached the netlist.  Each element read back as the plain default:
// everything the loop computed was lost.
//
// Root cause: the array_var import creates per-element alias wires only under
// `is_1d && !whole_accessed`.  A 1-D array that is whole-accessed fell through
// to a flat-wire-only fallback with no element aliases, and the element-field
// write path then had no per-element target and no stride.  Surelog only hands
// this declaration over as an array_VAR (rather than an array_NET, which
// materializes both forms) once a struct member is an ENUM -- hence the enum
// sensitivity.  Fix: materialize flat + per-element wires for a whole-accessed
// 1-D struct array too, as the array_net path and the multi-dim path do.
//
// This is OTBN's predec_vec / predec_mod, whose elem_idx-derived fields
// (op_a_qw_sel, op_b_elem0_sel, op_b_elem1_sel, acc_qw_sel, acc_merger_en)
// were all reading back as the default.  With this fix:
//     otbn_mac_bignum_fsm   cex -> PROVEN, co-sim 168 div -> NO_DIVERGENCE
//     otbn_instruction_fetch cex -> PROVEN
//
// `o_plain` is the no-enum control; `o_noWhole` covers the 1-D array that is
// NOT whole-accessed, which must keep using the per-element path it already
// handled correctly.
module array_elem_field_write_whole_default (
  input  logic [1:0] off,
  input  logic [1:0] i,
  output logic [9:0] o_enum,
  output logic [9:0] o_plain,
  output logic [9:0] o_noWhole
);
  typedef enum logic [1:0] { SelA = 2'b00, SelC = 2'b10 } sel_e;

  typedef struct packed {
    logic [1:0] qw;
    logic [2:0] e0;
    logic [2:0] acc;
    sel_e       sel;
  } d_t;

  typedef struct packed {
    logic [1:0] qw;
    logic [2:0] e0;
    logic [2:0] acc;
    logic [1:0] sel;
  } p_t;

  localparam d_t Def  = '{qw: 2'b00, e0: 3'b000, acc: 3'b000, sel: SelC};
  localparam p_t PDef = '{qw: 2'b00, e0: 3'b000, acc: 3'b000, sel: 2'b10};

  localparam int N = 4;

  d_t v [N];
  p_t vp[N];
  d_t vn[N];
  logic [1:0] idx[N];

  // One shared index computation, so the three arrays differ ONLY in the
  // property under test (whole-accessed, enum member) and not in the
  // expression that feeds them.
  always_comb
    for (int unsigned c = 0; c < N; c++) idx[c] = 2'(c) + off;

  // Whole-array default THEN per-element field writes: the combination that
  // broke.  Each element must end up with its own computed fields.
  always_comb begin
    v = '{default: Def};
    for (int unsigned c = 0; c < N; c++) begin
      v[c].qw  = idx[c];
      v[c].e0  = 3'({idx[c], 1'b0});
      v[c].acc = 3'(unsigned'(1) << idx[c]);
    end
  end

  // Same shape without the enum member (control).
  always_comb begin
    vp = '{default: PDef};
    for (int unsigned c = 0; c < N; c++) begin
      vp[c].qw  = idx[c];
      vp[c].e0  = 3'({idx[c], 1'b0});
      vp[c].acc = 3'(unsigned'(1) << idx[c]);
    end
  end

  // NOT whole-accessed: every element written field-by-field, no whole-array
  // assignment.  This already worked and must keep working.
  always_comb begin
    for (int unsigned c = 0; c < N; c++) begin
      vn[c].qw  = idx[c];
      vn[c].e0  = 3'({idx[c], 1'b0});
      vn[c].acc = 3'(unsigned'(1) << idx[c]);
      vn[c].sel = SelC;
    end
  end

  assign o_enum    = v [i];
  assign o_plain   = vp[i];
  assign o_noWhole = vn[i];
endmodule
