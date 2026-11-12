// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r31); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r31
module r31;
	logic [7:0] q;
	initial begin
		int i = 0;
		while (i < 4) begin
			q[i] = 1;
			i = i + 1;
		end
	end
endmodule

