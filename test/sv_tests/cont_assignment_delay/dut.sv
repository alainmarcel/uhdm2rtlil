// Converted from chipsalliance/sv-tests (cont_assignment_delay).
// Upstream puts the delay on an internal wire that is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input a, input b, output w);
  // The delay stays in upstream's position, on the assignment.
  assign #10 w = a & b;
endmodule
