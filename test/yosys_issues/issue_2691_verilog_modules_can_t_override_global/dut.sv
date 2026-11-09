// YosysHQ/yosys#2691 (open): verilog: modules can't override global type definitions
// https://github.com/YosysHQ/yosys/issues/2691
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): ports added: y = x ^ t over a new input t (the snippet had no ports); the shadowing typedef is unchanged

// ---- b0.sv
typedef logic [7:0] global_t;

module top(input logic [3:0] t, output logic [3:0] y);
	typedef logic [3:0] global_t;
	global_t x = 8'h42;
	always @(*) assert(x == 4'h2);
	assign y = x ^ t;
endmodule

