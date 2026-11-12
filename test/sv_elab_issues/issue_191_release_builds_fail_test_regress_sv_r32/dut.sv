// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r32); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r32
// issue 424 $bits on hierarchical reference
module r32_sub(input logic [3:0] x);
endmodule

module r32(input logic clk, input logic [3:0] d);
	r32_sub u (.x(d));
	always @(posedge clk) begin
		a_width: assert ($bits(u.x) == 4);
	end
endmodule

