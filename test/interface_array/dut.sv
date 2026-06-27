// Minimal interface-array test mirroring rp32 degu/hamster SoC usage:
// an array of interface instances, connected per-element to submodule modports.
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

module consumer (myif.sub b, output logic [7:0] o);
  assign o = b.dat & {8{b.vld}};
endmodule

module dut (
  input  logic       clk,
  input  logic       rst,
  input  logic [7:0] s0,
  input  logic [7:0] s1,
  output logic [7:0] o0,
  output logic [7:0] o1
);
  myif #(.W(8)) arr [2-1:0] (.clk(clk), .rst(rst));
  producer p0 (.b(arr[0]), .seed(s0));
  producer p1 (.b(arr[1]), .seed(s1));
  consumer c0 (.b(arr[0]), .o(o0));
  consumer c1 (.b(arr[1]), .o(o1));
endmodule
