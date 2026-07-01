// A parameter passed 2 levels down that references an interface struct field via
// a modport port: wrapper's `s.CFG.BUS.DAT` -> inner's SYS_DAT.  Mirrors the SoC
// tcb_lite_dev_gpio (modport port `sub`) -> tcb_dev_gpio `.SYS_DAT(sub.CFG.BUS.DAT)`.
package p;
  typedef struct packed { int unsigned DAT; } bus_t;
  typedef struct packed { bus_t BUS; } cfg_t;
endpackage

interface tif #(parameter p::cfg_t CFG = '{BUS: '{DAT: 32}});
  logic [CFG.BUS.DAT-1:0] data;
  modport sub (input data);
endinterface

module inner #(parameter int unsigned SYS_DAT = 8)
              (input logic clk, input logic [SYS_DAT-1:0] wdt, output logic [SYS_DAT-1:0] rdt);
  logic [SYS_DAT-1:0] reg_data;
  always_ff @(posedge clk) reg_data <= wdt;
  assign rdt = reg_data;
endmodule

module wrapper (input logic clk, tif.sub s, input logic [31:0] wdt, output logic [31:0] rdt);
  inner #(.SYS_DAT(s.CFG.BUS.DAT)) u_inner (.clk(clk), .wdt(wdt), .rdt(rdt));
endmodule

module iface_param_2level (input logic clk, input logic [31:0] wdt, output logic [31:0] rdt);
  tif s();
  wrapper u (.clk(clk), .s(s.sub), .wdt(wdt), .rdt(rdt));
endmodule
