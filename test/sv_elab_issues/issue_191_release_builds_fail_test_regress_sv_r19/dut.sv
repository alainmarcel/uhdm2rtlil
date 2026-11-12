// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r19); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r19
// defparam
module r19sub();
	parameter s = 0;
	initial begin
		if (s == 0)
			$error("bad");
	end
endmodule
module r19();
	r19sub inst();
	defparam inst.s = 1;
endmodule

