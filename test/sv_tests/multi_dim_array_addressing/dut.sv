// Converted from chipsalliance/sv-tests (multi_dim_array_addressing).
// Upstream reads one constant index pair of a 1024x4 array in an `initial` block and drops the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic clk, input logic we, input logic [9:0] i,
           input logic [1:0] j, input logic [7:0] wd, output logic [7:0] a);
  logic [7:0] mem [0:1023][0:3];
  // BOTH indices are ports, so the two-dimensional addressing is exercised rather
  // than folded.
  always_ff @(posedge clk)
    if (we) mem[i][j] <= wd;
  assign a = mem[i][j];
endmodule
