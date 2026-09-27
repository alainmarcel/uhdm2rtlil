// A dynamic bit-select on a plain vector declared with an ASCENDING
// (`logic [8:15]`) or NON-ZERO-LSB (`logic [15:8]`) range.  The dynamic
// lowering shifted the wire by the raw index -- `xa[8 + ai]` read bit 8+ai
// of an 8-bit wire and returned X -- while constant selects on such
// vectors were already mapped through the declared range (#697).  The
// index is now mapped to the bit position: ascending `right - idx`,
// descending `idx - low`.  The slang miter fails without the fix.
module ascending_vector_dyn_bitselect (
  input  logic [2:0]  ai,
  input  logic [8:15] xa,
  input  logic [15:8] xd,
  output logic        za,
  output logic        zd,
  output logic [3:0]  y
);
  assign za = xa[4'd8 + ai];
  assign zd = xd[4'd8 + ai];
  assign y  = 4'd8 + ai;
endmodule
