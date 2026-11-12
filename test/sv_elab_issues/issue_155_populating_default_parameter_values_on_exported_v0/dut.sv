// povik/sv-elab#155 (open): Populating default parameter values on exported blackbox module
// https://github.com/povik/sv-elab/issues/155
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
(* blackbox *)
module box();
	parameter foo = "bar";
endmodule

module top();
	box b();
endmodule

