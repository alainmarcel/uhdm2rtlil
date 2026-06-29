// Peripheral-bus root: a module drives `man[i].vld` (a FIELD of an array-of-
// modports port element) inside a genvar for-loop — like tcb_lite_lib_
// demultiplexer driving tcb_per[i].vld.  Does the drive reach arr[i].vld?
interface myif (input logic clk);
  logic vld, rdy;
  modport man (output vld, input rdy);
  modport sub (input  vld, output rdy);
endinterface
module driver #(parameter int N = 2) (myif.man man [N-1:0], input logic [N-1:0] v);
  for (genvar i = 0; i < N; i++) begin: g
    assign man[i].vld = v[i];
  end
endmodule
module reader (myif.sub s, output logic o);
  assign o = s.vld;
endmodule
module dut (input logic clk, input logic [1:0] v, output logic [1:0] o);
  myif arr [2-1:0] (.clk(clk));
  driver #(2) drv (.man(arr), .v(v));
  reader r0 (.s(arr[0]), .o(o[0]));
  reader r1 (.s(arr[1]), .o(o[1]));
endmodule
