// povik/sv-elab#400 (closed): Synth_gowin MULT - ALU problem
// https://github.com/povik/sv-elab/issues/400
// Code block(s) from the issue (variant h1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
(* blackbox *)
module alu();
	parameter FOO = 0;
	localparam BAR = FOO;
endmodule
module top();
	alu inst();
endmodule

