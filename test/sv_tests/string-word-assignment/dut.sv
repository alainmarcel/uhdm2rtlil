// Converted from chipsalliance/sv-tests (string-word-assignment).
// Upstream assigns a three-character literal to a 24-bit vector and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic [8 * 3 - 1 : 0] a, output logic w);
  always_comb a = "hi0";
  assign w = x;
endmodule
