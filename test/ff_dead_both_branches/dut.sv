// Exact CVA6 cva6_ptw.sv gpaddr_q pattern: a register assigned ONLY under a
// compile-time-false struct-param field guard `if (Cfg.RVH)` (RVH==0) in BOTH
// the reset branch AND the clocked (else) branch — i.e. a DEAD register.
// collect_live_assigned_signals must recognize it as dead (via const_cond_value
// resolving the hier_path field guard) and drop it; otherwise it becomes an
// async-reset FF with a non-constant reset value and proc/PROC_ARST aborts.
package cfg_pkg;
  typedef struct packed { int unsigned XLEN; bit RVH; } cfg_t;
  localparam cfg_t Cfg = '{XLEN: 64, RVH: 1'b0};
endpackage

module ff_dead_both_branches import cfg_pkg::*; #(parameter cfg_t Cfg = cfg_pkg::Cfg) (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic [7:0] d_i,
    output logic [7:0] dead_q,   // assigned only under Cfg.RVH (==0) in both branches
    output logic [7:0] live_q
);
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      live_q <= '0;
      if (Cfg.RVH) begin
        dead_q <= '0;
      end
    end else begin
      live_q <= d_i;
      if (Cfg.RVH) begin
        dead_q <= d_i;
      end
    end
  end
endmodule
