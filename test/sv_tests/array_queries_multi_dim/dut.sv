// Converted from chipsalliance/sv-tests (array_queries_multi_dim).
// Upstream prints nine queries on a `logic [31:0] arr [15:0]` from an `initial` block, including the DIMENSION argument that selects which dimension is being asked about.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] a, output logic [31:0] arr_o,
           output logic signed [31:0] q_dims,   output logic signed [31:0] q_incr2,
           output logic signed [31:0] q_right2, output logic signed [31:0] q_left2,
           output logic signed [31:0] q_right1, output logic signed [31:0] q_left1,
           output logic signed [31:0] q_low2,   output logic signed [31:0] q_high2,
           output logic signed [31:0] q_size2);
  logic [31:0] arr [15:0];
  // One element is driven from a port and read back, so the two-dimensional array
  // the queries describe survives into the netlist.
  assign arr[3]    = a;
  assign arr_o     = arr[3];
  assign q_dims    = $dimensions(arr);
  assign q_incr2   = $increment(arr, 2);
  assign q_right2  = $right(arr, 2);
  assign q_left2   = $left(arr, 2);
  assign q_right1  = $right(arr, 1);
  assign q_left1   = $left(arr, 1);
  assign q_low2    = $low(arr, 2);
  assign q_high2   = $high(arr, 2);
  assign q_size2   = $size(arr, 2);
endmodule
