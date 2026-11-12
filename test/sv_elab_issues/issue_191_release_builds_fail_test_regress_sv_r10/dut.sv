// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r10); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r10
// issue #129
module r10n();
wire n;
assign n = 0;
endmodule

module r10a();
wire t;
assign t = n1.n;
r10n n1();
endmodule

module r10b();
wire t;
r10n n1();
assign t = n1.n;
endmodule

