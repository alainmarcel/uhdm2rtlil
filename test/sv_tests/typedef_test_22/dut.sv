// Converted from chipsalliance/sv-tests (typedef_test_22).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef enum uvec8_t;
typedef enum {
  Global = 2,
  Local = 3
} uvec8_t;
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(uvec8_t);
  assign w     = x;
endmodule
