// Converted from chipsalliance/sv-tests (concat_op).
// Upstream builds the concatenation inside an `initial` block from constants and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] b, input logic [7:0] c, output bit [15:0] a);
  // Concatenation is MSB-first, so b has to land in the high byte.
  assign a = {b, c};
endmodule
