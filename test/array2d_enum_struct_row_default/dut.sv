// A whole-ROW assignment to a 2-D unpacked array of structs was emitted at
// ELEMENT width when the element struct contained an ENUM member.
//
//     typedef enum logic [1:0] { A, B } sel_e;
//     typedef struct packed { logic [1:0] f; sel_e e; } d_t;   // 4 bits
//     d_t m[2][12];                                            // 96 bits
//     m[0] = '{default: Def};      ->  assign $0\m [3:0] 4'0000
//
// One element (4 bits) instead of the whole 48-bit row, so every element of
// the row the following loop did not overwrite was left with NO DRIVER at all.
//
// Root cause: Surelog hands the SAME declaration over as an array_NET when the
// element is plain logic, but as an array_VAR as soon as one member is an
// ENUM.  Only the net path called materialize_flat_struct_array, which creates
// the per-ROW alias wires `\m[0]` / `\m[1]` (48 bits each) that a whole-row
// assignment needs; the var path created only the flat 96-bit wire, so the row
// select fell back to the ELEMENT stride.
//
// This is OTBN's otbn_mac_bignum_fsm `predec_multi[2][LatencyMax]`, whose
// `predec_multi[0] = '{default: PredecDynDefault}` wrote 4 of 48 bits and left
// 184 nets undriven -- and, through the modules that instantiate it,
// otbn_mac_bignum / otbn_instruction_fetch (184 each) and otbn_core (368).
//
// The ENUM member is what selects the broken path: replacing `sel_e e` with
// `logic [1:0] e` makes it correct, so `o_noenum` below is the control that
// must keep working.
//
// NOTE on the default VALUE.  The fill value here is deliberately all-zero.
// A separate, pre-existing bug zeroes a `'{default: <struct>}` whose struct
// carries an enum member -- it hits plain 1-D arrays too, which this fix does
// not touch -- so a non-zero default would confound the two.  With a zero
// default the symptom under test is unambiguous: the row bits the loop does
// not write are X (no driver) instead of 0.
module array2d_enum_struct_row_default (
  input  logic       row_i,
  input  logic [3:0] cyc_i,
  output logic [3:0] o_enum,     // 2-D array WITH an enum member
  output logic [3:0] o_noenum,   // same shape, no enum (control)
  output logic [3:0] o_tail,     // an element ONLY the row default drives
  output logic [1:0] o_deep      // 3-D, enum member
);
  typedef enum logic [1:0] { SelA = 2'b00, SelB = 2'b01, SelC = 2'b10 } sel_e;

  typedef struct packed {
    logic [1:0] f;
    sel_e       e;
  } d_t;

  typedef struct packed {
    logic [1:0] f;
    logic [1:0] e;
  } p_t;

  localparam d_t Def  = '{f: 2'b00, e: SelA};
  localparam p_t PDef = '{f: 2'b00, e: 2'b00};

  localparam int unsigned NLoop = 4;    // the loop covers only 4 of the 16
  localparam int unsigned NElem = 16;   // 2**$bits(cyc_i): every index in range

  d_t m  [2][NElem];
  p_t pm [2][NElem];

  always_comb begin
    m[0] = '{default: Def};
    for (int unsigned c = 0; c < NLoop; c++) m[0][c].f = 2'(c);
    m[1] = '{default: Def};
    for (int unsigned c = 0; c < NElem; c++) m[1][c].f = 2'(c);
  end

  always_comb begin
    pm[0] = '{default: PDef};
    for (int unsigned c = 0; c < NLoop; c++) pm[0][c].f = 2'(c);
    pm[1] = '{default: PDef};
    for (int unsigned c = 0; c < NElem; c++) pm[1][c].f = 2'(c);
  end

  assign o_enum   = m [row_i][cyc_i];
  assign o_noenum = pm[row_i][cyc_i];
  // Element 9 of row 0 is past the loop, so ONLY the row default drives it.
  // Without the fix this reads 4'bxxxx; with it, 4'b0000.
  assign o_tail   = m[0][9];

  // Three dimensions: the outer select must stride a whole PLANE.
  typedef struct packed { logic [1:0] g; sel_e e; } s_t;
  localparam s_t SDef = '{g: 2'b00, e: SelA};
  s_t deep [2][2][3];
  always_comb begin
    deep[0] = '{default: SDef};
    deep[1] = '{default: SDef};
    deep[0][0][0].g = 2'b11;
  end
  assign o_deep = deep[1][1][2].g;
endmodule
