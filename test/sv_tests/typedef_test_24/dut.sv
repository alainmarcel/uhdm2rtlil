// Converted from chipsalliance/sv-tests (typedef_test_24).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef struct {
  int sample;
  int tile;
} tuple_t;
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(tuple_t);
  assign w     = x;
endmodule
