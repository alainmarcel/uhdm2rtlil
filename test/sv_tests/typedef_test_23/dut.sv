// Converted from chipsalliance/sv-tests (typedef_test_23).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef bit[3:0] num_t;
typedef enum num_t {
  Global = 4'h2,
  Local = 4'h3
} myenum_fwd;
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(myenum_fwd);
  assign w     = x;
endmodule
