// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r7); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r7
module r7submod(input logic [3:0] i);
	logic [3:0] w;
	assign w = i + 1;
endmodule

module r7(input logic [3:0] i, output logic [3:0] out);
	r7submod submod(.i(i));
	always_comb begin
		automatic logic [3:0] w_fetched = submod.w;
		out <= w_fetched;
	end
endmodule

