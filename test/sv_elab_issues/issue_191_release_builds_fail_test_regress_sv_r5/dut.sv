// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r5); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r5
module r5;
	logic [1:0] [31:0] data;
	logic [1:0] s;

	always_comb begin
		reg [31:0] acc;
		for (int i = -10; i < 10; i++)
			acc += data[s][i+:8];
	end
endmodule

