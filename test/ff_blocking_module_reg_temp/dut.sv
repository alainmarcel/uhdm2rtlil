// A MODULE-level reg written with a BLOCKING assignment inside a clocked
// block and read by the following non-blocking assignments:
//   t = r + 1;  r <= t;  g <= t ^ (t >> 1);
// (verilog-ethernet axis_async_fifo's `rd_ptr_temp = rd_ptr_reg + 1;
// rd_ptr_reg <= rd_ptr_temp; rd_ptr_gray_reg <= ...`).  The in-flight value
// is tracked in ff_blocking_temps, but the registration looked up a bare
// `$0\t` while this FF path names the process temp `$0\t[3:0]`, so the
// lookup missed and `r <= t` read the flop's OLD value: the read pointer
// lagged one cycle (m_status_depth off by one, 273 co-sim divergences,
// invisible to a seq-4 bounded proof).  The temp is now resolved through
// the process's own map (find_own_temp_wire).
module ff_blocking_module_reg_temp (
  input  logic       clk,
  input  logic       en,
  output logic [3:0] r,
  output logic [3:0] g
);
  reg [3:0] t;
  always @(posedge clk) begin
    if (en) begin
      t = r + 1;
      r <= t;
      g <= t ^ (t >> 1);
    end
  end
endmodule
