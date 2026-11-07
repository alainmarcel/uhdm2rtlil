// YosysHQ/yosys#2691 (open): verilog: modules can't override global type definitions
// https://github.com/YosysHQ/yosys/issues/2691
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
typedef logic [7:0] global_t;

module top;
	typedef logic [3:0] global_t;
	global_t x = 8'h42;
	always @(*) assert(x == 4'h2);
endmodule

