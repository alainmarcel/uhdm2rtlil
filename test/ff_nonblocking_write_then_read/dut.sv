// In an always_ff body, a NON-blocking write must stay invisible to later
// reads in the same block (LRM 9.4.2: the register keeps its old value
// until the end of the time step).  verilog-ethernet ptp_clock_cdc's
// sample block does `sample_cnt_reg <= sample_cnt_reg + 1;` and then
// `if (sample_cnt_reg == 0) ...`: read_uhdm compared the in-flight
// `$0\sample_cnt_reg` (the NEXT value), so the accumulator reset, the
// active shift and the update toggle all fired one cycle early (249 co-sim
// divergences).  The comb-style FF importer's whole-wire write recorded the
// non-blocking RHS as the signal's current value, and the `if` condition
// import consulted that map.  Needs a declaration initialiser on the counter
// and a bit-select non-blocking write in the block to reach that path;
// without either it was already correct (kept as `cnt2`/`acc2` twins).
module ff_nonblocking_write_then_read (
  input  logic       clk,
  input  logic       s2,
  input  logic       s3,
  output logic [4:0] acc_o,
  output logic [2:0] cnt_o,
  output logic [3:0] active_o,
  output logic       upd_o,
  output logic [4:0] acc2_o,
  output logic [2:0] cnt2_o
);
  reg [4:0] acc = 0;
  reg [2:0] cnt = 0;
  reg [3:0] active = 0;
  reg       upd = 1'b0;
  always @(posedge clk) begin
    acc <= acc + 1;
    cnt <= cnt + 1;
    if (s2 && !s3) active[0] <= 1'b1;
    if (cnt == 0) begin
      active <= {active, s2 && !s3};
      acc <= 0;
      if (active != 0) upd <= !upd;
    end
  end
  reg [4:0] acc2;
  reg [2:0] cnt2;
  always @(posedge clk) begin
    acc2 <= acc2 + 1;
    cnt2 <= cnt2 + 1;
    if (cnt2 == 0) acc2 <= 0;
  end
  assign acc_o = acc; assign cnt_o = cnt; assign active_o = active; assign upd_o = upd;
  assign acc2_o = acc2; assign cnt2_o = cnt2;
endmodule
