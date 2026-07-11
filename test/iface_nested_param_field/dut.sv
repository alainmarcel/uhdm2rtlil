// Nested interface struct-PARAM field access `CFG.HSK.DLY` used inside the
// interface (tcb_lite_if: `req_dly [0:CFG.HSK.DLY]`).  3-level: CFG->HSK->DLY.
package p;
  typedef struct { int unsigned DLY; } hsk_t;
  typedef struct { hsk_t HSK; int unsigned W; } cfg_t;
  localparam cfg_t CFG_DEF = '{HSK: '{DLY: 3}, W: 8};
endpackage
interface tif #(parameter p::cfg_t CFG = p::CFG_DEF);
  logic [CFG.HSK.DLY-1:0] dly_reg;    // width uses CFG.HSK.DLY = 3 -> [2:0]
  modport sub (input dly_reg);
endinterface
module mem (tif.sub sub, output logic [2:0] o);
  assign o = sub.dly_reg;
endmodule
module iface_nested_param_field (input logic [2:0] d, output logic [2:0] o);
  tif s();
  assign s.dly_reg = d;
  mem u (.sub(s.sub), .o(o));
endmodule
