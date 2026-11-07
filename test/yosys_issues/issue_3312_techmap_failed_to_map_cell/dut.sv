// YosysHQ/yosys#3312 (closed): Techmap: Failed to map cell
// https://github.com/YosysHQ/yosys/issues/3312
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module custom_mul_test
	(
		input logic  in1_0, 
		input logic  in2_0,
		output logic out_0
	);
	assign out_0 = in1_0*in2_0;
endmodule

