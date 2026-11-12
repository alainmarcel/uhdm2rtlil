// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r9); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r9
module r9_blackbox_inner(output w);
endmodule

(* blackbox *)
module r9_blackbox(output w);
	r9_blackbox_inner inner(.*);
endmodule

module r9();
	r9_blackbox box();
endmodule

