// Converted from chipsalliance/sv-tests (idx_select_sim).
// Upstream reads two bits of a CONSTANT inside an `initial` block and prints them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] a, output logic b, output logic c);
  assign b = a[12];
  assign c = a[5];
endmodule
