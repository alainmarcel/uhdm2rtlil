// clk/rst layer: a child instance's port is connected to an INTERFACE SIGNAL
// access (`.clk(sub.clk)`) where sub is the parent's interface port — like
// tcb_dev_gpio `.clk(sub.clk)`.  Does sub.clk reach the child, or come out empty?
interface myif (input logic clk, input logic rst);
  logic sig;
  modport s (input clk, input rst, output sig);
endinterface
module child (input logic clk, input logic rst, output logic q);
  always_ff @(posedge clk, posedge rst) if (rst) q <= 1'b0; else q <= ~q;
endmodule
module mid (myif.s sub, output logic q);
  child c (.clk(sub.clk), .rst(sub.rst), .q(q));
  assign sub.sig = q;
endmodule
module dut (input logic clk, input logic rst, output logic q);
  myif mif (.clk(clk), .rst(rst));
  mid m (.sub(mif), .q(q));
endmodule
