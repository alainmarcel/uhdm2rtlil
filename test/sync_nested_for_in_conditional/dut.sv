// A for loop NESTED inside another for loop, under a conditional, in a
// clocked block.  The conditional for loop routes the block to the sync
// fallback path, whose loop unroller accepted only an assignment, an
// if/if-else or a begin block as the loop body: a nested `for` body hit
// "For loop unrolling not implemented for this statement type 15" and every
// inner write was DROPPED silently (`v` kept only its initial value).  The
// outer loop is now unrolled as statements, and the inner loop folds its
// bounds and index expressions with the outer variable's value.
module sync_nested_for_in_conditional (
  input  logic       clk,
  input  logic       rst,
  input  logic [3:0] x,
  output logic [3:0] v_o,
  output logic [7:0] cnt_o
);
  reg [3:0] v = 0;
  reg [7:0] cnt = 0;
  integer i, j;
  always @(posedge clk) begin
    cnt <= cnt + 1;
    if (x[3])
      for (i = 0; i < 2; i = i + 1)
        for (j = 0; j < 2; j = j + 1)
          v[i*2+j] <= v[i*2+j] ^ x[i*2+j];
    if (rst) begin
      cnt <= 0;
      v   <= 0;
    end
  end
  assign v_o = v; assign cnt_o = cnt;
endmodule
