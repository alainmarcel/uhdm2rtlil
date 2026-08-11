// Repro of the CVA6 branch_unit def-context struct-param staleness: a module
// with NO generate statements is imported from its AllModules DEFINITION
// (VpiName empty), where the struct parameter's param_assign holds the
// DECLARATION DEFAULT (`Cfg = CfgEmpty` == cfg_t'(0)) — not the elaborated
// override passed down the hierarchy.  `Cfg.RVC` then either fails to resolve
// ("Could not resolve struct member access" → guard stays a runtime wire →
// spurious latch; CVA6 jump_taken) or silently folds to the DEFAULT's 0
// instead of the overridden 1, killing the live `if (Cfg.RVC)` branch —
// functionally wrong (y_o stuck at 0).
package dcs_cfg_pkg;
  typedef struct packed {
    logic [31:0] XLEN;
    logic        RVC;
    logic        RVH;
  } cfg_t;
  // Same shapes as CVA6: a cast'(0) declaration default (elaborates to a
  // 1-operand pattern in the AllModules def) and a function-built override
  // (elaborates to a struct_var whose typespec members carry the values).
  // NOTE: read_verilog cannot parse these — this test is adjudicated against
  // read_slang (test_slang_equiv.ys), not the Verilog frontend.
  // NOTE an initial whole-struct assignment (`c = cfg_t'(0);`) before the
  // member writes makes Surelog's const-eval return the CAST value and drop
  // the member writes entirely (upstream Surelog bug, not hit by CVA6 —
  // build_config_pkg.sv declares `cfg` and assigns members only).
  localparam cfg_t CfgEmpty = cfg_t'(0);
  function automatic cfg_t build_config();
    cfg_t c;
    c.XLEN = 32;
    c.RVC  = 1'b1;
    c.RVH  = 1'b0;
    return c;
  endfunction
  localparam cfg_t CfgDefault = build_config();
endpackage

module dcs_leaf #(
    parameter dcs_cfg_pkg::cfg_t Cfg = dcs_cfg_pkg::CfgEmpty
) (
    input  logic a_i,
    input  logic b_i,
    output logic y_o,
    output logic z_o,
    output logic h_o
);
  always_comb begin
    z_o = a_i ^ b_i;
    y_o = 1'b0;
    h_o = 1'b0;
    if (Cfg.RVC) y_o = a_i & b_i;  // LIVE: override has RVC=1
    if (Cfg.RVH) h_o = a_i | b_i;  // DEAD: override has RVH=0
  end
endmodule

module dcs_mid #(
    parameter dcs_cfg_pkg::cfg_t Cfg = dcs_cfg_pkg::CfgEmpty
) (
    input  logic a_i,
    input  logic b_i,
    output logic y_o,
    output logic z_o,
    output logic h_o
);
  dcs_leaf #(.Cfg(Cfg)) u_leaf (.*);
endmodule

module def_ctx_struct_param (
    input  logic a_i,
    input  logic b_i,
    output logic y_o,
    output logic z_o,
    output logic h_o
);
  dcs_mid #(.Cfg(dcs_cfg_pkg::CfgDefault)) u_mid (.*);
endmodule
