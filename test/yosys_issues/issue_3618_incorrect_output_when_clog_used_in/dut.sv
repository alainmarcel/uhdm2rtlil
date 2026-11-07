// YosysHQ/yosys#3618 (closed): Incorrect output when `$clog` used in nested function calls
// https://github.com/YosysHQ/yosys/issues/3618
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top (o);
	output wire signed [31:0] o;
	parameter signed [31:0] X = 3;
	function automatic signed [$clog2(X) - 1:0] narrow;
		input reg signed [$clog2(X) - 1:0] inp;
		narrow = inp;
	endfunction
	function automatic signed [31:0] to_int;
		input reg signed [31:0] inp;
		to_int = inp;
	endfunction
	assign o = to_int(narrow(X));
endmodule

