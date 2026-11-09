// YosysHQ/yosys#1022 (closed): Error parsing systemverilog integer literal constants 
// https://github.com/YosysHQ/yosys/issues/1022
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): observable output bx = b ^ t over a new input t (b is a constant, so the co-sim was vacuous); the literal under test is unchanged

// ---- b0.sv
module test(
  output logic [31:0] b,
  input  logic [31:0] t,
  output logic [31:0] bx
);

  assign b = '0;

  assign bx = b ^ t;
endmodule

