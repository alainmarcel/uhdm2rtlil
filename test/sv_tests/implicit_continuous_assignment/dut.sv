// Converted from chipsalliance/sv-tests (implicit_continuous_assignment).
// Upstream assigns to the UNDECLARED `c`, which becomes an implicit net, and then never reads it -- so nothing confirms the implicit net exists or carries the value.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] x, output logic c_o);
  wire [3:0] a = 8;
  wire [3:0] b = x;
  // `c` is never declared: the assignment creates it as an implicit net, and reading
  // it back out is what makes that observable.
  assign c = | (a | b);
  assign c_o = c;
endmodule
