// A ROW-level default on a 2-D unpacked array silently discarded every element
// write that followed it.
//
//     t m[2][4];
//     m[0] = '{default: D};                 // row default
//     for (c) m[0][c].body = x + c;         // <- LOST
//
// A 2-D unpacked array whose ROWS are written whole is represented by per-row
// temps (`$0\m[0]`, `$0\m[1]`), not by one flat wire.  The element-field write
// took the masked DYNAMIC path, which reads and rewrites the FLAT wire — a
// different object — so the row assignment overwrote every element write that
// came after it, and the array read back as the bare default.
//
// The dynamic path was taken even though every index folds to a constant: the
// bit offset is accumulated through Mul/Add CELLS, so it is never
// `is_fully_const()` however literal the indices are.  Tracking the constant
// offset alongside it lets a wholly-static write address the row temp directly.
//
// The whole-array form (`m = '{default: '{default: D}}`) always worked, because
// that registers the base in current_comb_values and keeps the chain intact —
// which is exactly what made this so easy to miss.
package p;
  typedef struct packed {
    logic [6:0] body;
    logic       tmp;      // non-zero in the default
  } t;
  localparam t D = '{body: 7'd0, tmp: 1'b1};
endpackage

module array2d_row_default_elem_write (
  input  logic [6:0] x,
  input  logic [1:0] c0,
  input  logic       r0,
  output logic [7:0] o_row,    // row-level default + element writes
  output logic [7:0] o_whole,  // whole-array default + identical writes (control)
  output logic [7:0] o_dynrow, // dynamic row index, still element-written
  output logic [7:0] o_second  // the row that got ONLY the default
);
  p::t m1[2][4];
  p::t m2[2][4];

  always_comb begin
    m1[0] = '{default: p::D};
    m1[1] = '{default: p::D};
    for (int unsigned c = 0; c < 4; c++) m1[0][c].body = x + 7'(c);
  end

  always_comb begin
    m2 = '{default: p::D};
    for (int unsigned c = 0; c < 4; c++) m2[0][c].body = x + 7'(c);
  end

  assign o_row    = m1[0][c0];
  assign o_whole  = m2[0][c0];
  assign o_dynrow = m1[r0][c0];
  assign o_second = m1[1][c0];
endmodule
