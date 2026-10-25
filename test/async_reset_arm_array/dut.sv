module dut (input logic clk, input logic rst, input logic push, input logic [2:0] din, input logic [1:0] ra, output logic [2:0] q);
   reg [2:0] fifo [3:0];
   reg [1:0] top;
   always @(posedge clk or posedge rst)
      if (rst) begin
         top <= 0; fifo[0] <= 0; fifo[1] <= 0; fifo[2] <= 0; fifo[3] <= 0;
      end else if (push) begin
         fifo[top] <= din; top <= top + 2'd1;
      end
   assign q = fifo[ra];
endmodule
