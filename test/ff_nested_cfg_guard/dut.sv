// A register assigned ONLY under a compile-time-false guard that is a NESTED
// field of a wide, FUNCTION-BUILT struct parameter (`CFG.u.eccEn`), and never
// assigned in the reset branch.  The dead-guarded signal must be dropped;
// otherwise it survives as an async-reset FF with no constant reset value and
// yosys' PROC_ARST rejects the whole process with
//     Async reset ... yields non-constant value 1'm for signal ...
// (hpdcache_memctrl's data_flush_read_q, guarded by HPDcacheCfg.u.eccEn, where
// HPDcacheCfg comes from hpdcacheBuildConfig(HPDcacheUserCfg).)
package cfgp;
  typedef struct packed {
    logic [31:0] ways;
    logic [31:0] sets;
    logic        eccEn;
    logic        lowLatency;
  } user_cfg_t;

  typedef struct packed {
    user_cfg_t   u;
    logic [31:0] accessWidth;
    logic [31:0] setWidth;
  } cfg_t;

  function automatic user_cfg_t setUserCfg();
    user_cfg_t c;
    c.ways       = 32'd4;
    c.sets       = 32'd64;
    c.eccEn      = 1'b0;
    c.lowLatency = 1'b1;
    return c;
  endfunction

  function automatic cfg_t buildCfg(input user_cfg_t u);
    cfg_t c;
    c.u           = u;
    c.accessWidth = 32'd128;
    c.setWidth    = 32'd6;
    return c;
  endfunction

  localparam user_cfg_t UserCfg = setUserCfg();
  localparam cfg_t      CFG     = buildCfg(UserCfg);
endpackage

module child
  import cfgp::*;
#(
    parameter cfg_t CFG = cfgp::CFG
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in,
    output logic [3:0] idx_q,
    output logic       flush_q
);
  always_ff @(posedge clk or negedge rst_n) begin : idx_ff
    if (!rst_n) begin
      idx_q <= '0;
    end else begin
      if (in || (CFG.u.eccEn && !in)) begin
        idx_q <= idx_q + 4'd1;
      end
      if (CFG.u.eccEn) begin
        flush_q <= in;
      end
    end
  end
endmodule

//  The guard's parameter arrives through an INSTANCE override, which is how
//  hpdcache_memctrl sees HPDcacheCfg.
module dut
  import cfgp::*;
#(
    parameter cfg_t CFG = cfgp::CFG
) (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in,
    output logic [3:0] idx_q,
    output logic       flush_q
);
  child #(.CFG(CFG)) u_child (
      .clk(clk), .rst_n(rst_n), .in(in), .idx_q(idx_q), .flush_q(flush_q));
endmodule
