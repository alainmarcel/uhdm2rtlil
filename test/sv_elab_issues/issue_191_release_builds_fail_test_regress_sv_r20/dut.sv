// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r20); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r20
// recursion
module r20(input [31:0] x, output [31:0] q);
	function automatic [31:0] pow;
		input [31:0] base;
		input [31:0] exp;
		begin
			if (exp > 0)
				pow = base * pow(base, exp - 1);
			else
				pow = 1;
		end
	endfunction
	assign q = pow(x, 3);
endmodule

