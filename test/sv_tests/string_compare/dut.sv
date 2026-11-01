// Converted from chipsalliance/sv-tests (string_compare).
// Upstream assigns the same literal to two vectors and prints both.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic eq, output logic w);
  bit [8*14:1] a;
  bit [8*14:1] b;
  always_comb begin a = "Test"; b = "Test"; end
  assign eq = (a == b);
  assign w  = x;
endmodule
