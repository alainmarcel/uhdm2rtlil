// YosysHQ/yosys#6165 (open): Fails to substitute module code  for instance in particular situations
// https://github.com/YosysHQ/yosys/issues/6165
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): outputs qi / qg observe q_inst / q_gold (top had no output)

// ---- b0.sv
// Two registers that are textbook-identical: posedge FF, input d, initial value 0.
// The only difference is WHERE the FF lives (instance vs. same module).
module ff1 (input logic clk, input logic d, output logic q);
  always_ff @(posedge clk) q <= d;
endmodule

module top (input logic clk, input logic d, output logic qi, output logic qg);
  assign qi = q_inst;
  assign qg = q_gold;
  logic q_inst = 0;                       // driven by instance output port
  logic q_gold = 0;                       // driven by always_ff in this module
  ff1 u0 (clk, d, q_inst);
  always_ff @(posedge clk) q_gold <= d;
  always @(posedge clk) assert (q_inst == q_gold);
endmodule

