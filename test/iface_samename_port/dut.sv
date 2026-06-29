// Root #2 repro hypothesis: the interface INSTANCE and the connected module's
// interface PORT share the same name ("bus") — like the degu SoC's
// `.tcb_ifu(tcb_ifu)`.  Does the core's `bus.vld` drive reach the parent?
interface myif (input logic clk, input logic rst);
  logic vld, rdy, trn;
  assign trn = vld & rdy;
  modport man (input clk, input rst, output vld, input rdy, input trn);
  modport sub (input clk, input rst, input  vld, output rdy, input trn);
endinterface
module core (myif.man bus);          // port named "bus"
  assign bus.vld = 1'b1;
endmodule
module mon (myif.sub s, input logic g, output logic o);
  assign s.rdy = g;
  assign o = s.trn;
endmodule
module dut (input logic clk, input logic rst, input logic g, output logic o);
  myif bus (.clk(clk), .rst(rst));   // instance ALSO named "bus"
  core c  (.bus(bus));               // .bus(bus) — same name both sides
  mon  mn (.s(bus), .g(g), .o(o));
endmodule
