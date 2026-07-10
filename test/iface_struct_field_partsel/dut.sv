// Repro of r5p_soc_memory address slice: part-select of an interface STRUCT
// FIELD (sub.req.adr) with a computed interface-localparam lower bound (sub.OFF)
// and a module-localparam upper bound (ADR = $clog2(SIZE)).
package p;
  typedef struct { int unsigned DAT; } bus_t;
  typedef struct { bus_t BUS; } cfg_t;
  localparam cfg_t CFG_DEF = '{BUS: '{DAT: 32}};
  typedef struct packed { logic [31:0] adr; } req_t;
endpackage
interface tif #(parameter p::cfg_t CFG = p::CFG_DEF);
  localparam int unsigned BYT = CFG.BUS.DAT/8;   // 4
  localparam int unsigned OFF = $clog2(BYT);     // 2
  p::req_t req;
  modport sub (input req);
endinterface
module mem #(parameter int unsigned SIZE = 4096) (tif.sub sub, output logic [11:0] o);
  localparam int unsigned ADR = $clog2(SIZE);      // 12
  logic [ADR-sub.OFF-1:0] a;
  assign a = sub.req.adr[ADR-1:sub.OFF];           // sub.req.adr[11:2]
  assign o = 12'(a);
endmodule
module iface_struct_field_partsel (input logic [31:0] adr, output logic [11:0] o);
  tif s();
  assign s.req.adr = adr;
  mem u (.sub(s.sub), .o(o));
endmodule
