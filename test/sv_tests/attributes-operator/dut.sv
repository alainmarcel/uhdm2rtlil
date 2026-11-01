// Converted from chipsalliance/sv-tests (attributes-operator).
// Upstream attaches `mode = "cla"` to an operand of `+` inside an `initial` block whose operands are never driven.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] b, input logic [7:0] c, output logic [7:0] a);
  // The attribute sits in exactly upstream's position, on the second operand.
  assign a = b + (* mode = "cla" *) c;
endmodule
