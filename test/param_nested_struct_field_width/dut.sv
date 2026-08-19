// A width expression that reads a NESTED field of a struct MODULE PARAMETER
// (`CFG.u.sidWidth`), where the parameter's default comes from a package
// localparam built by a function -- the shape of CVA6's
// `parameter hpdcache_cfg_t HPDcacheCfg` + `HPDcacheCfg.u.accessWords`.
package pk;
  typedef struct packed {
    int unsigned sidWidth;
    int unsigned dataWidth;
  } user_cfg_t;

  typedef struct packed {
    user_cfg_t   u;
    int unsigned derived;
  } cfg_t;

  function automatic user_cfg_t mku();
    user_cfg_t c;
    c.sidWidth  = 3;
    c.dataWidth = 32;
    return c;
  endfunction

  function automatic cfg_t build(user_cfg_t uu);
    cfg_t c;
    c.u       = uu;
    c.derived = uu.dataWidth * 2;
    return c;
  endfunction

  localparam user_cfg_t UCFG = mku();
  localparam cfg_t      CFG  = build(UCFG);
endpackage

module dut #(
    parameter  pk::cfg_t CFG      = pk::CFG,
    localparam int       SID_W    = CFG.u.sidWidth,   // NESTED  -> was 0
    localparam int       DATA_W   = CFG.derived,      // one level -> ok
    localparam int       NOUT     = CFG.u.dataWidth /
                                    CFG.u.sidWidth,   // nested / nested
    localparam int       NLOG     = $clog2(NOUT),
    localparam type      sel_t    = logic [NLOG-1:0],
    localparam type      sid_t    = logic [SID_W-1:0],
    localparam type      data_t   = logic [DATA_W-1:0]
) (
    input  logic  clk_i,
    input  sid_t  sid_i,
    input  data_t data_i,
    input  sel_t  sel_i,
    output logic  o
);
  assign o = ^{sid_i, data_i, sel_i};
endmodule
