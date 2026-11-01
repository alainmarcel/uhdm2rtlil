// Converted from chipsalliance/sv-tests (non_idx_part_select).
// Upstream takes the part-select inside an `initial` block and drops (or prints) the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] a, output logic [3:0] b);
  assign b = a[11:8];
endmodule
