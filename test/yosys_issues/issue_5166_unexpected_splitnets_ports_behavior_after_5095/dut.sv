// YosysHQ/yosys#5166 (closed): Unexpected splitnets -ports behavior after #5095 (name single bit arrays as arrays)
// https://github.com/YosysHQ/yosys/issues/5166
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test_module (
  a,
  b,
  x,
  y
);
  input logic [0:0] a;
  output logic [0:0] b;
  input logic [1:0] x;
  output logic [1:0] y;
  assign b = a;
  assign y = x;
endmodule

