module dut (input clk, input rst, input c, input c2, input [7:0] d, input [2:0] sel, output [7:0] y);
  logic [7:0] p [4:0] = '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
  logic [7:0] nn [3:0];
  assign nn[0] = d; assign nn[1] = d ^ 8'h11; assign nn[2] = d ^ 8'h22; assign nn[3] = d ^ 8'h33;
  always_ff @(posedge clk) begin
    if (rst) p <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
    else if (c) begin
      p[3:0] <= nn;
      if (c2) p[4] <= p[4] + 8'd1;
    end else if (c2) p <= '{8'd0, 8'd0, 8'd0, 8'd0, 8'd0};
  end
  assign y = p[sel < 3'd5 ? sel : 3'd0];  // in range: an out-of-range read is X in one netlist and 0 in Verilator
endmodule
