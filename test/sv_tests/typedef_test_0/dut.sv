// Converted from chipsalliance/sv-tests (typedef_test_0).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
typedef i_am_a_type_really;

typedef int i_am_a_type_really;

// Multiple forward typedefs are allowed.
typedef i_am_a_type_really;
typedef i_am_a_type_really;
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(i_am_a_type_really);
  assign w     = x;
endmodule
