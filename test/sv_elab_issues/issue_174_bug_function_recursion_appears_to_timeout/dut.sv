// povik/sv-elab#174 (closed): BUG: Function recursion appears to timeout
// https://github.com/povik/sv-elab/issues/174
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module func_recurse_top(
	input wire [3:0] inp,
	output wire [3:0] out1, out2
);
	function automatic [3:0] pow_a;
		input [3:0] base, exp;
		begin
			pow_a = 1;
			if (exp > 0)
				pow_a = base * pow_a(base, exp - 1);
		end
	endfunction

	function automatic [3:0] pow_b;
		input [3:0] base, exp;
		begin
			pow_b = 1;
			if (exp > 0)
				pow_b = base * pow_b(base, exp - 1);
		end
	endfunction

	assign out1 = pow_a(inp, 3);
	assign out2 = pow_b(2, 2);
endmodule

