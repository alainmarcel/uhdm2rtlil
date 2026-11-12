// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r11); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r11
module r11(input a, input b, input c, output y);
	let andor(a, b, c) = a && b || c;
	assign y = andor(a, b, c);
endmodule

