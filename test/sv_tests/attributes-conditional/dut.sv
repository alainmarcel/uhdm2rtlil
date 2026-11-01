// Converted from chipsalliance/sv-tests (attributes-conditional).
// Upstream attaches `no_glitch` to a conditional expression inside an `initial` block whose operands are never driven.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input bit b, input bit c, input bit d, output bit a);
  // The attribute sits in exactly upstream's position, between `?` and the true arm.
  assign a = b ? (* no_glitch *) c : d;
endmodule
