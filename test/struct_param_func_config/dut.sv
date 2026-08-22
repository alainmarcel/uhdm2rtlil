// Struct parameter computed by a chain of constant functions and handed
// down through an instantiation override — the "evalFunc" shape from CVA6's
// HPDcacheCfg (hpdcacheBuildConfig(hpdcacheSetConfig())):
//   - the package param's RHS stays an UNFOLDED func_call in UHDM;
//   - the override hand-off (`child #(.Cfg(Cfg))`) clones an opaque anonymous
//     struct_var and the child-instance param is stamped a garbage 0 value;
//   - Surelog's compile-time eval annotates the function-arg typespec clone's
//     members with the true values (typespec_member Actual_value).
// The importer must fold `Cfg.u.flag1` reads (and guards) from those
// annotations — trusting ExprEval's whole-expression reduce read the stamped
// 0 and hpdcache_ctrl_pe kept dead st1 logic live (lowLatency read as 0).
// The `s.field[k]`-independent members (d) and widths derived from members
// (w) guard against the assembled-constant width regression
// (hpdcache_sync_buffer's ports collapsed 84->22 bits).
package p;
  typedef struct packed {
    int unsigned a;
    bit flag1;
    bit flag2;
  } ucfg_t;
  typedef struct packed {
    ucfg_t u;
    int unsigned d;
  } cfg_t;
  function automatic ucfg_t setcfg();
    ucfg_t c;
    c.a = 7;
    c.flag1 = 1'b1;
    c.flag2 = 1'b0;
    return c;
  endfunction
  function automatic cfg_t build(input ucfg_t u);
    cfg_t r;
    r.u = u;
    r.d = u.a * 2;
    return r;
  endfunction
  localparam ucfg_t U = setcfg();
  localparam cfg_t C = build(U);
endpackage

module child
  import p::*;
#(
  parameter cfg_t Cfg = '0
) (
  input  logic                 x,
  output logic                 y,
  output logic                 z,
  output logic [Cfg.u.a-1:0]   w
);
  always_comb begin
    y = 1'b0;
    if (!Cfg.u.flag1) begin
      y = x;               // dead: flag1 == 1
    end
  end
  assign z = Cfg.u.flag1 ? x : 1'b0;   // = x
  assign w = {Cfg.u.a{x}};             // 7 bits of x
endmodule

module struct_param_func_config
  import p::*;
#(
  parameter cfg_t Cfg = p::C
) (
  input  logic       x,
  output logic       y,
  output logic       z,
  output logic [6:0] w
);
  child #(.Cfg(Cfg)) u_c (.x(x), .y(y), .z(z), .w(w));
endmodule
