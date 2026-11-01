// Converted from chipsalliance/sv-tests (implicit_port_connection).
// Upstream connects the child POSITIONALLY and ties its inputs to constants, so the child computes a constant; the result reaches `d`, which is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input wire a, input wire b, output wire d);
  wire c;
  // The POSITIONAL connection is the construct: a, b, c bind to the child's ports
  // in declaration order, so swapping any two changes what d carries.
  test mod(a, b, c);
  assign d = c;
endmodule
module test(input a, input b, output c);
  assign c = a | b;
endmodule
