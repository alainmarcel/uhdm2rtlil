// YosysHQ/yosys#4115 (closed): Bug: Shifts (in both directions) consider the operand signed under some conditions in CXXRTL
// https://github.com/YosysHQ/yosys/issues/4115
// Code block(s) from the issue (variant tc); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): observable output out2 = (c >> 32'hfffffff8) ^ c (the huge right shift makes out constant 0, so the co-sim was vacuous; a wrong shift still shows on out2)

// ---- b0.sv
module top(
input logic [31:0] c,

output logic [31:0] out,
output logic [31:0] out2
);
  assign out2 = (c >> 32'hfffffff8) ^ c;
  // assign out = c >> 28'hfffffff8;
  assign out = c >> 32'hfffffff8;
endmodule

