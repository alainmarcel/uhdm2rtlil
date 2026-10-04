// A shift-register array written ONLY with for-loop indices and read with a
// dynamic index (verilog-ethernet axis_srl_fifo).  The importer unrolls the
// loop, so every write is a constant-index write and the array must become
// per-element registers.  The array-access scanner used to score the loop
// variable `k` as a dynamic index: the array became a $mem with a $memrd
// but NO $memwr (the unrolled writes went to element wires), and the read
// returned 0 forever -- 262 of 302 co-sim cycles diverged on axis_srl_fifo.
module dut (
  input        clk,
  input        rst,
  input        shift,
  input  [7:0] d,
  input  [1:0] ptr,
  output [7:0] q
);
  reg [7:0] data_reg [3:0];
  integer k;

  assign q = data_reg[ptr];

  always @(posedge clk) begin
    if (rst) begin
      for (k = 0; k < 4; k = k + 1) data_reg[k] <= 8'd0;
    end else if (shift) begin
      data_reg[0] <= d;
      for (k = 0; k < 3; k = k + 1) data_reg[k+1] <= data_reg[k];
    end
  end
endmodule
