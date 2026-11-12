// povik/sv-elab#243 (open): Inference of multi-dimensional memories
// https://github.com/povik/sv-elab/issues/243
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input logic [3:0] a1, input logic [3:0] a2, input logic clk,
			output logic [7:0] y, input logic [7:0] d);
	logic [7:0] array[16][16];
	always @(posedge clk) begin
		array[a1][a2] <= d;
		y <= array[a1][a2];
	end
endmodule

