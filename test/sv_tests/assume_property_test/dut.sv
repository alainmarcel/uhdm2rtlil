// Converted from chipsalliance/sv-tests (assume_property_test).
// Upstream never drives `clk` or `a`, so the concurrent `assume property` constrains nothing and a frontend that dropped it would look identical.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic a, output logic o);
  assume property ( @(posedge clk) (a == 1));
  assign o = a;
endmodule
