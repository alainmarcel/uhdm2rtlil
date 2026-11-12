// povik/sv-elab#87 (open): Optimize out self-assignment from DFF reset patterns
// https://github.com/povik/sv-elab/issues/87
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top #(
	parameter bit RST_Q = 0
) (
	input logic clk,
	input logic rst,
	input logic d,
	output logic q
);

always_ff @(posedge clk or posedge rst) begin
	if (rst) begin
		if (RST_Q)
			q <= '0;
	end else begin
		q <= d;
	end
end

endmodule

