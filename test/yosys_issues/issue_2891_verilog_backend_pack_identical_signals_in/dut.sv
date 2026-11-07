// YosysHQ/yosys#2891 (open): Verilog backend: pack identical signals in concatenation
// https://github.com/YosysHQ/yosys/issues/2891
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module mymodule # (
  parameter int unsigned Width = 16
) (
	input logic a_i,
	output logic [Width-1:0] y_o
);
  assign y_o = {Width{a_i}};
endmodule

