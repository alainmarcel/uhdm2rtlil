// povik/sv-elab#160 (closed): error: condition cannot be matched to any signal from the event list
// https://github.com/povik/sv-elab/issues/160
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- c0.sv
module r19(input clk, input rst, input x, output q);
	typedef struct packed {
		logic x;
		logic q;
		logic clk;
		logic rst;
	} foo_t;
	foo_t bar;

	assign bar.clk = clk;
	assign bar.rst = rst;
	assign bar.x = x;
	assign q = bar.q;

	always_ff @(posedge bar.clk or negedge bar.rst) begin
		if (~bar.rst)
			bar.q <= 0;
		else
			bar.q <= bar.x;
	end
endmodule

