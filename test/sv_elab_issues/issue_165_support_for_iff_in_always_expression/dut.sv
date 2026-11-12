// povik/sv-elab#165 (closed): Support for `iff` in `always` expression
// https://github.com/povik/sv-elab/issues/165
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module block ();
	wire clk = 0;
	wire en = 0;
	wire a = 0;
	reg y;
	always @(posedge clk iff en == 1)
		y <= a;
endmodule

