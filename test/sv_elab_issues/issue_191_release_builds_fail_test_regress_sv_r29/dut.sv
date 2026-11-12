// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r29); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r29
// pr 373 async pattern with size cast
module r29(input clk, input rst, input d, output reg q);
	always @(posedge clk or posedge rst)
		if (rst == 1) q <= 1'b0;
		else q <= d;
endmodule

