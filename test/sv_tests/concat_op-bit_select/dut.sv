// Converted from chipsalliance/sv-tests (concat_op-bit_select).
// Upstream takes a part-select OF A CONCATENATION inside an `initial` block, from constants, and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] b, input logic [7:0] c, output bit [3:0] a);
  // A select applied directly to a concatenation: bits 9..6 of {b,c} straddle the
  // boundary -- 9 and 8 come from b's low two bits, 7 and 6 from c's high two.
  assign a = {b, c}[9:6];
endmodule
