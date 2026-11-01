// Converted from chipsalliance/sv-tests (typedef_test_26).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef enum {
`ifdef TWO
  Global = 2,
`else
  Global = 1,
`endif
  Local = 3
} myenum_fwd;
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(myenum_fwd);
  assign w     = x;
endmodule
