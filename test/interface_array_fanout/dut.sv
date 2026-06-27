// Whole interface-array connection: a module with an ARRAY of interface ports
// (`m[N]`) connected with `.m(arr)` (the whole array) — mirrors rp32 degu SoC's
// `tcb_lite_lib_demultiplexer .man(tcb_per)`.
interface myif #(parameter int W = 8) (input logic clk, input logic rst);
  logic         vld;
  logic [W-1:0] dat;
  modport man (input clk, input rst, output vld, output dat);
  modport sub (input clk, input rst, input  vld, input  dat);
endinterface

module producer (myif.man b, input logic [7:0] seed);
  assign b.vld = 1'b1;
  assign b.dat = seed;
endmodule

// array of interface ports, driven per element from a single source interface
module fanout (myif.sub s, myif.man m [2-1:0]);
  assign m[0].vld = s.vld;
  assign m[0].dat = s.dat;
  assign m[1].vld = s.vld;
  assign m[1].dat = s.dat + 8'd1;
endmodule

module consumer (myif.sub b, output logic [7:0] o);
  assign o = b.dat & {8{b.vld}};
endmodule

module dut (
  input  logic       clk,
  input  logic       rst,
  input  logic [7:0] sd,
  output logic [7:0] o0,
  output logic [7:0] o1
);
  myif #(.W(8)) src       (.clk(clk), .rst(rst));
  myif #(.W(8)) arr [2-1:0] (.clk(clk), .rst(rst));
  producer p (.b(src), .seed(sd));
  fanout   f (.s(src), .m(arr));   // whole-array connection
  consumer c0 (.b(arr[0]), .o(o0));
  consumer c1 (.b(arr[1]), .o(o1));
endmodule
