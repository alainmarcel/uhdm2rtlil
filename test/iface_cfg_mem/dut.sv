// Memory sized by an interface STRUCT PARAMETER field accessed through a modport
// port: `logic [s.CFG.BUS.DAT-1:0] mem [0:...]`.  Mirrors the degu SoC's
// r5p_soc_memory (`logic [sub.CFG.BUS.DAT-1:0] mem [0:SIZ/(DAT/8)-1]`).
package tpkg;
  typedef struct packed { int unsigned DAT; } bus_t;
  typedef struct packed { bus_t BUS; } cfg_t;
endpackage

interface tif #(parameter tpkg::cfg_t CFG = '{BUS: '{DAT: 32}});
  logic [CFG.BUS.DAT-1:0] req;
  logic [CFG.BUS.DAT-1:0] rsp;
  modport sub (input req, output rsp);
endinterface

module mem_core (input logic clk, input logic [7:0] adr, tif.sub s);
  logic [s.CFG.BUS.DAT-1:0] mem [0:255];
  always_ff @(posedge clk) begin
    mem[adr] <= s.req;
    s.rsp   <= mem[adr];
  end
endmodule

module iface_cfg_mem (input logic clk, input logic [7:0] adr, input logic [31:0] din, output logic [31:0] dout);
  tif s();
  assign s.req = din;
  assign dout  = s.rsp;
  mem_core u (.clk(clk), .adr(adr), .s(s.sub));
endmodule
