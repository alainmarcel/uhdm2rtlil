// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r33); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r33
// issue 423 read of an unpacked array parameter via a hierarchical reference
module r33_leaf #(parameter int P[2] = '{0, 3}) ();
endmodule

module r33(output logic [31:0] w);
	r33_leaf u ();
	assign w = u.P[1];
endmodule

