// A struct parameter whose value is a package CONSTANT FUNCTION, taken at its
// DEFAULT by the module being elaborated as the TOP -- PULP obi_pkg's
//   localparam obi_cfg_t ObiDefaultConfig = obi_default_cfg(32, 32, 1, ...);
//   module obi_uart #(parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig)
// Surelog leaves that call UNFOLDED (even under -elabuhdm), so the reader
// evaluated the function body with no call context: every formal was
// unresolved, the struct came out empty, and `logic [Cfg.DataWidth-1:0]`
// became ONE BIT.  cheshire's obi_uart returned a single bit of UART read data
// (21 diverging co-simulated cycles) and obi_uart_tx / apb_uart / reg_uart_wrap
// the same through it.  The companion test pkg_struct_param_const_function
// passes the parameter EXPLICITLY, which always worked -- the default is the gap.
// read_verilog cannot parse a struct parameter from a package function, so the
// gates are the read_slang miter and the structural width proof.
package cfg_pkg;
  // the nested optional config: a pattern-valued package parameter passed
  // as the function's struct-typed argument (obi_pkg's ObiMinimalOptionalConfig)
  typedef struct packed {
    bit          UseAtop;
    int unsigned AUserWidth;
  } opt_t;
  localparam opt_t MinimalOpt = '{
    UseAtop:    1'b0,
    AUserWidth: 3
  };
  typedef struct packed {
    bit          UseRReady;
    int unsigned AddrWidth;
    int unsigned DataWidth;
    int unsigned IdWidth;
    opt_t        Opt;
  } cfg_t;
  function automatic cfg_t default_cfg(int unsigned AddrWidth, int unsigned DataWidth,
                                       int unsigned IdWidth, opt_t Opt);
    default_cfg = '{
      UseRReady: 1'b0,
      AddrWidth: AddrWidth,
      DataWidth: DataWidth,
      IdWidth:   IdWidth,
      Opt:       Opt
    };
  endfunction
  localparam cfg_t DefaultCfg = default_cfg(32, 32, 1, MinimalOpt);
endpackage

module leaf #(parameter cfg_pkg::cfg_t Cfg = cfg_pkg::DefaultCfg)
  (input logic [Cfg.DataWidth-1:0] d_i, output logic [Cfg.DataWidth-1:0] d_o);
  logic [Cfg.DataWidth-1:0] rsp_data;
  always_comb begin
    rsp_data = '0;
    rsp_data = d_i;
  end
  assign d_o = rsp_data;
endmodule

module dut #(parameter cfg_pkg::cfg_t Cfg = cfg_pkg::DefaultCfg)
  (input  logic [Cfg.DataWidth-1:0] d_i,
   output logic [Cfg.DataWidth-1:0] d_o,
   output logic [31:0] w_o,
   output logic [31:0] au_o);
  assign w_o  = Cfg.DataWidth;
  assign au_o = Cfg.Opt.AUserWidth;
  leaf #(.Cfg(Cfg)) u_l (.d_i(d_i), .d_o(d_o));
endmodule
