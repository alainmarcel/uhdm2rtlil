// Converted from chipsalliance/sv-tests (cont_assignment_net_delay).
// Upstream puts the delay on the NET DECLARATION of a wire that is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input a, input b, output w_o);
  // The delay stays in upstream's position, on the net declaration.
  wire #10 w;
  assign w   = a & b;
  assign w_o = w;
endmodule
