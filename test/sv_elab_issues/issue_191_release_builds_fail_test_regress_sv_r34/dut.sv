// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r34); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r34
// issue 129 a terminating forever loop is unrolled and synthesized
module r34(output logic [3:0] q);
	initial begin
		int i = 0;
		forever begin
			if (i == 4) break;
			q[i] = 1;
			i = i + 1;
		end
	end
endmodule

