// Reading an interface modport struct MEMBER in a continuous assign:
// `assign adr = mon.req.adr;`.  Mirrors degu SoC tcb_lite_lib_decoder
// (`assign adr = mon.req.adr`) whose empty result made the address decode X ->
// wrong peripheral select -> GPIO never written.
package p;
  typedef struct packed { logic [31:0] adr; logic [31:0] dat; } req_t;
endpackage
interface tif;
  p::req_t req;
  modport mon (input req);
endinterface
module dec (tif.mon mon, output logic [31:0] a);
  logic [31:0] adr;
  assign adr = mon.req.adr;
  assign a = adr;
endmodule
module iface_member_read_assign (input logic [31:0] din, output logic [31:0] a);
  tif s();
  assign s.req.adr = din;
  assign s.req.dat = '0;
  dec u (.mon(s.mon), .a(a));
endmodule
