// YosysHQ/yosys#4115 (closed): Bug: Shifts (in both directions) consider the operand signed under some conditions in CXXRTL
// https://github.com/YosysHQ/yosys/issues/4115
// Code block(s) from the issue (variant tc); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(
input logic [31:0] c,

output logic [31:0] out
);
  // assign out = c >> 28'hfffffff8;
  assign out = c >> 32'hfffffff8;
endmodule

