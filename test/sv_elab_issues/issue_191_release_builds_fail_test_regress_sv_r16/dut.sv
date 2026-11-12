// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r16); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r16
module r16(input [3:0] in, input invert);
	wire [3:0] out;
	xor X[3:0] (out, in, invert);
endmodule

