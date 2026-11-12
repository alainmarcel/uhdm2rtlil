// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r1
// To catch regressions around snippets which previously failed
// to parse

module r1;
	logic a [0:1];
	assign a[1'b0] = 1;
endmodule

