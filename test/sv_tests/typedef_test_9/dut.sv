// Converted from chipsalliance/sv-tests (typedef_test_9).
// Upstream declares the typedef at $unit scope and leaves the module EMPTY, so the type is never used and its geometry is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
parameter j = 3;
parameter k = 2;
typedef bit data_t;

typedef data_t my_array_t [k:0][j:0];
module test(input logic x, output logic signed [31:0] nbits, output logic w);
  // The typedef is kept verbatim; $bits of the TYPE is what a typedef test is
  // about, and the witness gives the co-sim something that moves.
  assign nbits = $bits(my_array_t);
  assign w     = x;
endmodule
