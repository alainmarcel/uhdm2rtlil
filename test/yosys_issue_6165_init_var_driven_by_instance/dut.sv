// YosysHQ/yosys#6165: a variable with a declaration initialiser (`logic q_inst
// = 0`) whose driver is a submodule's OUTPUT PORT was lowered by yosys to a
// constant continuous driver, silently disconnecting the instance -- q_inst
// stuck at 0 while the textbook-identical in-module register followed d.
// Both registers must track d one clock behind from a reset value of 0.
module ff1 (input logic clk, input logic d, output logic q);
  always_ff @(posedge clk) q <= d;
endmodule
module dut (input logic clk, input logic d, output logic q_inst, output logic q_gold);
  logic qi = 0;
  logic qg = 0;
  ff1 u0 (clk, d, qi);
  always_ff @(posedge clk) qg <= d;
  assign q_inst = qi;
  assign q_gold = qg;
endmodule
