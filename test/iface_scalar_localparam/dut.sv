package p;
  typedef struct { int unsigned DAT; } bus_t;
  typedef struct { bus_t BUS; } cfg_t;
  localparam cfg_t CFG_DEF = '{BUS: '{DAT: 32}};
endpackage
interface tif #(parameter p::cfg_t CFG = p::CFG_DEF);
  localparam int unsigned BYT = CFG.BUS.DAT/8;   // 4
  localparam int unsigned OFF = $clog2(BYT);     // 2
  logic [31:0] adr;
  modport sub (input adr);
endinterface
module mem (tif.sub sub, output logic [11:0] o);
  // Mirrors r5p_soc_memory: a module localparam (ADR) combined with an
  // interface scalar localparam (sub.OFF) in a range/slice.  ADR=12, OFF=2 ->
  // width 10, slice [11:2].
  localparam int unsigned ADR = 12;
  logic [ADR-sub.OFF-1:0] a;
  assign a = sub.adr[ADR-1:sub.OFF];
  assign o = 12'(a);
endmodule
module iface_scalar_localparam (input logic [31:0] adr, output logic [11:0] o);
  tif s();
  assign s.adr = adr;
  mem u (.sub(s.sub), .o(o));
endmodule
