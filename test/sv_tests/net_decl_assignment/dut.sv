// Converted from chipsalliance/sv-tests (net_decl_assignment).
// Upstream's net-declaration assignment drives an internal wire that is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input a, input b, output w_o);
  // A net-declaration assignment is a continuous assignment in the declaration;
  // it has to drive the net just as a separate `assign` would.
  wire w = a & b;
  assign w_o = w;
endmodule
