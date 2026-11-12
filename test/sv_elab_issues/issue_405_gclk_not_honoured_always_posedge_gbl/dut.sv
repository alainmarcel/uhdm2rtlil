// povik/sv-elab#405 (open): `(* gclk *)` not honoured: `always @(posedge gbl)` on a global-clock variable elaborates to a `$dff` clocked by `'x` instead of a `$ff`
// https://github.com/povik/sv-elab/issues/405
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module t (input logic clk, input logic d, output logic q);
  (* gclk *) reg gbl;              // yosys' global clock: the formal time step
  always @(posedge gbl) q <= d;
endmodule

