// IEEE 1800-2023 23.10.2.1: a parameter value assignment by ORDERED list,
// #(W, K), binds in declaration order.
module sub #(parameter int W = 2, parameter int K = 1)
            (input logic [W-1:0] a, output logic [W-1:0] y);
  assign y = a + W'(K);
endmodule

module dut(input logic [7:0] a, output logic [7:0] y8, output logic [3:0] y4);
  sub #(8, 5) u8(.a(a), .y(y8));
  sub #(4)    u4(.a(a[3:0]), .y(y4));
endmodule
