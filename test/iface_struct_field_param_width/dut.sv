// Interface struct FIELD width from a nested interface struct PARAMETER
// (`logic [CFG.BUS.ADR-1:0] adr` inside req_t), read via `mon.req.adr`.
// Mirrors degu SoC tcb_lite_if req_t + tcb_lite_lib_decoder `assign adr =
// mon.req.adr`, where adr collapsed to 1 bit -> address decode broken.
package p;
  typedef struct { int unsigned ADR; int unsigned DAT; } bus_t;
  typedef struct { bus_t BUS; } cfg_t;
  localparam cfg_t CFG_PER = '{BUS: '{ADR: 32, DAT: 32}};
endpackage
interface tif #(parameter p::cfg_t CFG = p::CFG_PER);
  typedef struct {
    logic [CFG.BUS.ADR-1:0] adr;
    logic [CFG.BUS.DAT-1:0] wdt;
  } req_t;
  req_t req;
  modport mon (input req);
endinterface
module dec #(parameter int unsigned ADR = 32) (tif.mon mon, output logic [ADR-1:0] a);
  logic [ADR-1:0] adr;
  assign adr = mon.req.adr;
  assign a = adr;
endmodule
module iface_struct_field_param_width (input logic [31:0] din, output logic [31:0] a);
  tif #(p::CFG_PER) s();
  assign s.req.adr = din;
  assign s.req.wdt = '0;
  dec #(.ADR(32)) u (.mon(s.mon), .a(a));
endmodule
