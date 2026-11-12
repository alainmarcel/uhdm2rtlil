// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r8); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r8
module r8();
// `bit` type memories have implicit initialization
bit _bit [7:0];
logic _logic [7:0];
reg _reg [7:0];
endmodule

