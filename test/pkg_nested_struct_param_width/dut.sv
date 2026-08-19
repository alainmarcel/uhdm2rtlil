package pk;
  typedef struct packed { int unsigned sidWidth; int unsigned dataWidth; } user_cfg_t;
  typedef struct packed { user_cfg_t u; int unsigned derived; } cfg_t;   // NESTED
  function automatic user_cfg_t mku(); user_cfg_t c; c.sidWidth=3; c.dataWidth=32; return c; endfunction
  function automatic cfg_t build(user_cfg_t uu); cfg_t c; c.u=uu; c.derived=uu.dataWidth*2; return c; endfunction
  localparam user_cfg_t UCFG = mku();
  localparam cfg_t CFG = build(UCFG);
  typedef logic [CFG.u.sidWidth-1:0] sid_t;      // NESTED field  -> 3 bits
  typedef logic [CFG.derived-1:0]    data_t;     // top-level field -> 64 bits
endpackage
module dut (input logic clk_i, input pk::sid_t sid_i, input pk::data_t data_i, output logic o);
  assign o = ^{sid_i, data_i};
endmodule
