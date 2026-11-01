// Converted from chipsalliance/sv-tests (array_queries).
// Upstream prints all eight queries on a packed `logic [31:0]` from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, output logic [31:0] arr_o,
           output logic signed [31:0] q_unpacked_dims, output logic signed [31:0] q_dims,
           output logic signed [31:0] q_incr, output logic signed [31:0] q_right,
           output logic signed [31:0] q_left, output logic signed [31:0] q_low,
           output logic signed [31:0] q_high, output logic signed [31:0] q_size);
  logic [31:0] arr;
  assign arr             = a;
  assign arr_o           = arr;
  assign q_unpacked_dims = $unpacked_dimensions(arr);
  assign q_dims          = $dimensions(arr);
  assign q_incr          = $increment(arr);
  assign q_right         = $right(arr);
  assign q_left          = $left(arr);
  assign q_low           = $low(arr);
  assign q_high          = $high(arr);
  assign q_size          = $size(arr);
endmodule
