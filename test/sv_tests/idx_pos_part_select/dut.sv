// Converted from chipsalliance/sv-tests (idx_pos_part_select).
// Upstream reads an ASCENDING indexed part-select of an array it never drives, inside an `initial` block, and drops the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [15:0] a, output logic [3:0] b);
  assign b = a[11+:4];
endmodule
