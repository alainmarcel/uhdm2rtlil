// A blocking write to a module-level reg read by later non-blocking
// assignments, in a clocked block that ALSO shifts an unpacked array in a
// for loop.  The array shift is a "memory write inside a for loop", which
// routes the whole block through the legacy sync path — and that path never
// threaded a blocking write's value into later RHS reads: `r <= t` read the
// flop's OLD value.  verilog-ethernet axis_async_fifo's read side has
// exactly this shape (`m_axis_pipe_reg[j] <= m_axis_pipe_reg[j-1]` in a
// loop, then `rd_ptr_temp = rd_ptr_reg + 1; rd_ptr_reg <= rd_ptr_temp;`):
// the read pointer lagged a cycle, m_status_depth was off by one, 273
// co-sim divergences under a green seq-4 proof.
module sync_path_blocking_temp (
  input  logic       clk,
  input  logic       en,
  input  logic [3:0] d,
  output logic [3:0] r,
  output logic [3:0] g,
  output logic [3:0] o
);
  reg [3:0] t;
  reg [3:0] p [1:0];
  integer j;
  always @(posedge clk) begin
    for (j = 1; j > 0; j = j - 1) begin
      p[j] <= p[j-1];
    end
    p[0] <= d;
    if (en) begin
      t = r + 1;
      r <= t;
      g <= t ^ (t >> 1);
    end
  end
  assign o = p[1];
endmodule
