// An interface localparam derived from the interface's CFG struct parameter
// (`CFG_BUS_BYT = CFG.BUS.DAT/8`, `CFG_BUS_SIZ = $clog2($clog2(CFG_BUS_BYT)+1)`)
// used as a struct-field WIDTH (`logic [CFG_BUS_SIZ-1:0] siz`).  A module that
// reaches the interface only through a modport PORT (`my_if.man m`, e.g. a core
// synthesised standalone like rp32's r5p_degu) must resolve those localparams.
// Surelog now exposes the interface's elaborated param_assigns on the
// interface_inst (NetlistElaboration elab_interface_) and the frontend folds
// the (constant) value; previously CFG_BUS_SIZ/BYT became undriven wires.
package q;
  typedef struct { int unsigned DAT; } bus_t;
  typedef struct { bus_t BUS; } cfg_t;
  localparam cfg_t CFG_A = '{BUS:'{DAT:32}};   // DAT=32 -> BYT=4, SIZ=2
endpackage
interface my_if import q::*; #(parameter cfg_t CFG = CFG_A)(input logic clk);
  localparam int unsigned CFG_BUS_BYT = CFG.BUS.DAT/8;
  localparam int unsigned CFG_BUS_OFF = $clog2(CFG_BUS_BYT);
  localparam int unsigned CFG_BUS_SIZ = $clog2(CFG_BUS_OFF+1);
  typedef struct packed {
    logic [CFG_BUS_SIZ-1:0] siz;
    logic [CFG_BUS_BYT-1:0] byt;
  } req_t;
  req_t req;
  modport man (input clk, output req);
endinterface
// Standalone top with the interface as a PORT (no instantiation).
module iface_port_localparam import q::*; (
  input  logic       clk,
  my_if.man          m,
  output logic [1:0] o_siz,   // CFG_BUS_SIZ = 2 bits wide
  output logic [3:0] o_byt    // CFG_BUS_BYT = 4 bits wide
);
  assign m.req.siz = 2'b10;
  assign m.req.byt = 4'b1010;
  assign o_siz = m.req.siz;
  assign o_byt = m.req.byt;
endmodule
