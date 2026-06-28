// Minimal repro: an interface with an INTERNAL continuous assign computing a
// signal (trn = vld & rdy) — like tcb_lite_if.  The computed signal must be
// driven for instances (the SoC's tcb_*.trn_dly were undriven).
interface myif (input logic clk, input logic rst);
  logic vld, rdy;
  logic trn;
  assign trn = vld & rdy;          // interface-internal logic
  modport man (input clk, input rst, output vld, input rdy, input trn);
  modport sub (input clk, input rst, input  vld, output rdy, input trn);
endinterface

module drv (myif.man m);
  assign m.vld = 1'b1;
endmodule

module mon (myif.sub s, input logic g, output logic o);
  assign s.rdy = g;
  assign o = s.trn;                // read the interface-computed signal
endmodule

module dut (input logic clk, input logic rst, input logic g, output logic o);
  myif inst (.clk(clk), .rst(rst));
  drv d (.m(inst));
  mon mn (.s(inst), .g(g), .o(o));
endmodule
