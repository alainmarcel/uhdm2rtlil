// YosysHQ/yosys#4113 (closed): Bug: Logic and arithmetic left shifts sometimes overflow the output signal
// https://github.com/YosysHQ/yosys/issues/4113
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(input logic [31:0] a, input logic [31:0] b, output logic [4:0] out_data);
  assign out_data = b[5:1] << a[31:27];
endmodule

