// A module-level localparam built by a constant function over
// `$bits(<port>.<member>)`, where the port's type is a TYPE PARAMETER bound
// by the parent (cheshire apb_uart_wrap:
//   localparam obi_cfg_t ObiCfg = obi_default_cfg($bits(apb_req_i.paddr), 32, 1, ...)
// ).  Surelog compiled the port's type NAME in the definition, where the
// parameter still holds its default `logic`, so `$bits(apb_req_i)` folded to
// 1 and `$bits(apb_req_i.paddr)` found no member: the call stayed an unfolded
// assignment pattern with its formals unbound, every `Cfg.*`-sized member
// collapsed to one bit, and the 72-bit OBI request struct measured 7 (its
// field count) through the whole apb_uart / reg_uart_wrap hierarchy.
package cfg_pkg;
  typedef struct packed {
    int unsigned AddrWidth;
    int unsigned DataWidth;
  } cfg_t;
  function automatic cfg_t default_cfg(int unsigned AddrWidth,
                                       int unsigned DataWidth);
    default_cfg = '{AddrWidth: AddrWidth, DataWidth: DataWidth};
  endfunction
endpackage

module wrap #(
  parameter type apb_req_t = logic
) (
  input  apb_req_t    apb_req_i,
  input  logic [31:0] d_i,
  output logic [31:0] d_o,
  output logic [7:0]  w_o
);
  localparam int W_MEMBER = $bits(apb_req_i.paddr);
  localparam int W_PORT   = $bits(apb_req_i);
  localparam cfg_pkg::cfg_t Cfg =
      cfg_pkg::default_cfg($bits(apb_req_i.paddr), 32);
  typedef struct packed {
    logic [Cfg.AddrWidth-1:0] addr;
    logic [Cfg.DataWidth-1:0] wdata;
  } req_t;
  req_t r;
  assign r = '{addr: apb_req_i.paddr, wdata: d_i};
  assign d_o = r.wdata ^ {27'd0, r.addr};
  assign w_o = W_MEMBER[3:0] * W_PORT[3:0];   // 5 * 6 = 30
endmodule

module dut (
  input  logic [4:0]  a_i,
  input  logic [31:0] d_i,
  output logic [31:0] d_o,
  output logic [7:0]  w_o
);
  typedef struct packed {
    logic [4:0] paddr;
    logic       psel;
  } apb_req_t;
  apb_req_t apb_req;
  assign apb_req = '{paddr: a_i, psel: 1'b1};
  wrap #(.apb_req_t(apb_req_t)) u (.apb_req_i(apb_req), .d_i, .d_o, .w_o);
endmodule
