module mem2reg_test3( input clk, input [8:0] din_a, output reg [7:0] dout_a, output [7:0] dout_b);
reg [7:0] dint_c [0:7];
always @(posedge clk)
  begin
      {dout_a[0], dint_c[3]} <= din_a;
  end
assign dout_b = dint_c[3];
endmodule
