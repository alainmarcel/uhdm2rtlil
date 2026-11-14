// povik/sv-elab#165 (closed): Support for `iff` in `always` expression
// https://github.com/povik/sv-elab/issues/165
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module block (__o_a, __o_clk, __o_en, __o_y);
	wire clk = 0;
	wire en = 0;
	wire a = 0;
	reg y;
	always @(posedge clk iff en == 1)
		y <= a;

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_a;
  assign __o_a = a;
  output logic __o_clk;
  assign __o_clk = clk;
  output logic __o_en;
  assign __o_en = en;
  output logic __o_y;
  assign __o_y = y;
endmodule

