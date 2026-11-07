// YosysHQ/yosys#3748 (open): write_smt2: bugs caused by the '>>' operator under certain circumstances
// https://github.com/YosysHQ/yosys/issues/3748
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (res, offset);
  output [3:0] res; // 4-bit
  input signed [4:0] offset; // 5-bit
  assign res = 4'sb1000 >> offset;
 endmodule

