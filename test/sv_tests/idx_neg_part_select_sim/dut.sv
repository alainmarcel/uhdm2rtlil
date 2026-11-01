// Converted from chipsalliance/sv-tests (idx_neg_part_select_sim).
// Upstream reads `a[15-:8]` of a CONSTANT inside an `initial` block and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] a, output logic [7:0] b);
  assign b = a[15-:8];
endmodule
