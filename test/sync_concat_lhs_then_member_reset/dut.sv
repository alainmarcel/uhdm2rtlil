// A concat-LHS non-blocking write followed by a plain write to one of its
// members in the trailing reset arm -- verilog-ethernet ptp_td_phc's
//   {td_update_reg, td_update_cnt_reg} <= td_update_cnt_reg + 1;
//   ... if (rst) begin td_update_cnt_reg <= 0; td_update_reg <= 1'b0; end
// and, in the same block, a whole-register shift of td_shift_reg, slice
// loads into it, then `if (rst) td_shift_reg <= '1`: the reset mux took the
// SHIFT (the exact-key entry) as its else value and dropped the slice loads.
// The block takes the sync fallback path (a for loop nested inside a
// conditional), whose flush pushed every pending entry as its own sync
// action: the whole-concat action AND the member's reset mux both landed on
// the same bits and the unconditional concat action won, so the cadence
// counter never reset (40 co-sim divergences).  The flush now emits one
// update per base wire with every bit taken from the LATEST pending write.
module sync_concat_lhs_then_member_reset (
  input  logic       clk,
  input  logic       rst,
  input  logic [3:0] x,
  output logic [7:0] cnt_o,
  output logic       upd_o,
  output logic [3:0] v_o,
  output logic [15:0] sh_o
);
  // whole-register shift, slice loads, then a whole-register reset: the
  // reset mux's else value must carry the slice loads, not just the shift
  reg [15:0] sh = 16'hffff;
  reg [7:0] cnt = 0;
  reg       upd = 1'b0;
  reg [3:0] v = 0;
  integer i;
  always @(posedge clk) begin
    {upd, cnt} <= cnt + 1;
    if (x[3])
      for (i = 0; i < 4; i = i + 1)
        v[i] <= v[i] ^ x[i];
    sh <= {1'b1, sh} >> 1;
    if (x[2]) begin
      sh[3:0]  <= x;
      sh[11:8] <= ~x;
    end
    if (rst) begin
      cnt <= 0;
      upd <= 1'b0;
      sh  <= 16'hffff;
    end
  end
  assign sh_o = sh;
  assign cnt_o = cnt; assign upd_o = upd; assign v_o = v;
endmodule
