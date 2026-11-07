// YosysHQ/yosys#5212 (closed): multiple drivers on a variable in a module change values of input ports when using `prep`
// https://github.com/YosysHQ/yosys/issues/5212
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module simple_sub(a, b, a_out, b_out, diff);
  input [7:0] a;
  wire [7:0] a;
  output [7:0] a_out;
  wire [7:0] a_out;
  input [7:0] b;
  wire [7:0] b;
  output [7:0] b_out;
  wire [7:0] b_out;
  wire [7:0] conflict_wire;
  output [7:0] diff;
  wire [7:0] diff;
  assign diff = a - a;
  assign a_out = a;
  assign b = a;
  assign b_out = a;
  assign conflict_wire = a;
endmodule

