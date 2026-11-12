// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r2); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r2
module r2;
	logic [1:0] a [0:1];
	always_comb
		a[1'b0-:1] = '{0};
endmodule

