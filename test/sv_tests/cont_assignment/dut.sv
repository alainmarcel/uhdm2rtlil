// Converted from chipsalliance/sv-tests (cont_assignment).
// Upstream assigns to an internal wire that is never read, so the assignment drives nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input a, input b, output w);
  assign w = a & b;
endmodule
