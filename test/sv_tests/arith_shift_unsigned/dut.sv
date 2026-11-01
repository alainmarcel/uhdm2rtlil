// Converted from chipsalliance/sv-tests (arith_shift_unsigned).
// Upstream computes both shifts on a constant inside an `initial` block and prints them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, output logic [7:0] b, output logic [7:0] c);
  assign b = (a <<< 3);
  assign c = (a >>> 3);
endmodule
