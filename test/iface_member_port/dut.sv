// Interface modport struct MEMBER as a child port ACTUAL: `.sys_wdt(sub.req.wdt)`.
// Mirrors degu SoC tcb_lite_dev_gpio -> tcb_dev_gpio (.sys_wdt(sub.req.wdt)),
// which produced an EMPTY `connect \sys_wdt { }` -> GPIO write path dead.
package p;
  typedef struct packed { logic [31:0] wdt; logic wen; } req_t;
endpackage
interface tif;
  p::req_t req;
  modport sub (input req);
endinterface
module inner (input logic [31:0] sys_wdt, input logic sys_wen, output logic [31:0] o);
  assign o = sys_wen ? sys_wdt : '0;
endmodule
module wrapper (tif.sub sub, output logic [31:0] o);
  inner u (.sys_wdt(sub.req.wdt), .sys_wen(sub.req.wen), .o(o));
endmodule
module iface_member_port (input logic [31:0] din, input logic en, output logic [31:0] o);
  tif s();
  assign s.req.wdt = din;
  assign s.req.wen = en;
  wrapper w (.sub(s.sub), .o(o));
endmodule
