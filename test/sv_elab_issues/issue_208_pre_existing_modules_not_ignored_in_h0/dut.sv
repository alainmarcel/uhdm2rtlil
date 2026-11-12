// povik/sv-elab#208 (closed): Pre-existing modules not ignored in read_slang embedded script
// https://github.com/povik/sv-elab/issues/208
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module primi(d, q, clk);
input wire clk;
input wire d;
output reg q;
always @(posedge clk)
	q <= d;
endmodule

