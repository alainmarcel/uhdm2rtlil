// thread_comb_if both-arms-agree: when BOTH arms of an if write the SAME
// value to a block-local (`nop = 1'b1` in then AND else), the merge skipped
// recording it into current_comb_values, so the later `y = !nop` read the
// stale pre-if value.  Distilled from CVA6 hpdcache_ctrl_pe, where the
// uncacheable-request handling sets `st1_nop = 1'b1` in both arms of
// `if (cachedir_hit_i)` and `nop = st1_nop | st2_nop` read 0, raising
// rtab_req_ready_o while a stage-1 fence request was pending (1/2000 co-sim
// divergence, cycle-113 state).
module comb_if_both_arms_value(
    input logic v, a, b, c, h, p,
    output logic y,
    output logic u
);
always_comb begin : blk
  automatic logic nop;
  nop = 1'b0;
  u = 1'b0;
  if (v) begin
    if (a) begin
      u = 1'b0;
    end
    else if (b) begin
      nop = 1'b1;
    end
    else if (c) begin
      if (!p) begin
        nop = 1'b1;
      end
      else begin
        if (!h) begin
          u = 1'b1;
          nop = 1'b1;
        end
        else begin
          nop = 1'b1;
        end
      end
    end
  end
  y = !nop;
end
endmodule
