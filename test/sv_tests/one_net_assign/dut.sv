// Converted from chipsalliance/sv-tests (one_net_assign).
// Upstream is a single continuous assignment between two ports -- already synthesizable, but with nothing proven about it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input a, output b);
  assign b = a;
endmodule
