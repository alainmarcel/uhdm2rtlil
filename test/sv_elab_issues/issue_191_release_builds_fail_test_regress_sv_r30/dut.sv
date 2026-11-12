// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r30); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r30
// commit dc07ede8 bmux lowering with Sx in pattern
module r30(input logic [1:0] sel, output logic [1:0] y);
	always_comb begin
		y = 2;
		casez (sel)
			2'b10: y = 0;
			2'bxx: y = 1;
			2'b01: y = 3;
		endcase
	end
endmodule

