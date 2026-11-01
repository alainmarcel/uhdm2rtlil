// Converted from chipsalliance/sv-tests (implicit_port).
// Upstream declares `c` and assigns it but never brings it out, so the module has two inputs and NO outputs and synthesises to nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input [3:0] a, input [3:0] b, output [3:0] c_o);
  wire [3:0] c;
  assign c   = a | b;
  assign c_o = c;
endmodule
