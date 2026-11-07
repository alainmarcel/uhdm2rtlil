// YosysHQ/yosys#6401 (closed): [Bug Report] data type casts to signed types lose the target signedness, causing incorrect synthesis
// https://github.com/YosysHQ/yosys/issues/6401
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(input [7:0] a, output [63:0] y);
  assign y = byte'(a);
endmodule

