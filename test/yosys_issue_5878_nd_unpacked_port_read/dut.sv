// YosysHQ/yosys#5878 (sweep row): an element of a THREE-dimensional unpacked
// INPUT PORT.  The port's per-element wires are numbered flat, and a read
// `en[i][j][k]` took its FIRST index as the flat element -- en[1][0][3] read
// flat bit 1.  1-bit elements hide it from a width check, so the test reads
// a 1-bit and a 4-bit array, by constant and by dynamic indices, with
// non-zero low bounds, and the issue's foreach write loop over them.
module dut(input logic clk,
           input logic en [1:0][0:0][3:1],
           input logic [3:0] w [2:1][1:0][2:0],
           input logic [0:0] i, input logic [1:0] k, input logic [1:0] a, b, c,
           output logic [5:0] e, output logic [3:0] w_c, w_d, output logic e_d,
           output logic out);
  assign e = {en[1][0][3], en[1][0][2], en[1][0][1],
              en[0][0][3], en[0][0][2], en[0][0][1]};
  assign w_c = w[2][0][1];
  // dynamic indices, kept in range (an out-of-range read is X on both sides,
  // which a SAT miter cannot compare)
  assign w_d = w[a[0] + 2'd1][b[0]][c % 2'd3];
  assign e_d = en[i][0][k % 2'd3 + 2'd1];
  logic [2:0] my_array [1:0][0:0][3:1];
  always_ff @(posedge clk)
    foreach (my_array[s, d, r])
      if (en[s][d][r]) my_array[s][d][r] <= w[s+1][d][r-1][2:0];
  logic t;
  always_comb begin
    t = 1'b0;
    foreach (my_array[s, d, r]) t ^= ^my_array[s][d][r];
  end
  assign out = t;
endmodule
