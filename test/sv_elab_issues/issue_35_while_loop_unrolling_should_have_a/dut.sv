// povik/sv-elab#35 (closed): While loop unrolling should have a limit
// https://github.com/povik/sv-elab/issues/35
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- c0.sv
module top(input logic [7:0] bound);
	always_comb for (int i = 0; i < bound; i++)
		;
endmodule

// ---- c1.sv
module top2(input logic [15:0] bound);
	always_comb for (int i = 0; i < bound; i++)
		;
endmodule

// ---- c2.sv
module top3();
	always_comb
		for (int i = 0; i < 100; i++)
		for (int j = 0; j < 100; j++)
		;
endmodule

