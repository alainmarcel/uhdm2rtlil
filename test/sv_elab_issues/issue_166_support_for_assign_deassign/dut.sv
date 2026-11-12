// povik/sv-elab#166 (open): Support for `assign`-`deassign`
// https://github.com/povik/sv-elab/issues/166
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(clk, q, d, clr, set);

input clk, d, clr, set;
output q;
logic q;

always @(clr or set)
	if (clr)
		assign q = 0;
	else if (set)
		assign q = 1;
	else
		deassign q;

always @(posedge clk)
	q <= d;

endmodule

