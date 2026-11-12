// povik/sv-elab#158 (open): Support `.prev` on enum values
// https://github.com/povik/sv-elab/issues/158
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
typedef enum {r, g, b} color_t;
module top(input color_t color1, output color_t color2);
	always_comb
		color2 = color1.prev;
endmodule

