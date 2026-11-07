// YosysHQ/yosys#3292 (closed): ERROR: Multiple edge sensitive events found for this signal!
// https://github.com/YosysHQ/yosys/issues/3292
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module ResetController (
	clk,
	rstTrigger,
	locked,
	rst,
	rstStart
);
	parameter CYCLE_OF_RESET_SEQUENCE = 10000;
	input wire clk;
	input wire rstTrigger;
	input wire locked;
	output reg rst;
	output reg rstStart;
	reg [$clog2(CYCLE_OF_RESET_SEQUENCE):0] count;
	localparam BasicTypes_FALSE = 1'b0;
	localparam BasicTypes_TRUE = 1'b1;
	always @(posedge clk or posedge rstTrigger)
		if (rstTrigger || !locked) begin
			count <= 0;
			rst <= BasicTypes_TRUE;
		end
		else if (rst) begin
			count <= count + 1;
			rst <= (count >= CYCLE_OF_RESET_SEQUENCE ? BasicTypes_FALSE : BasicTypes_TRUE);
		end
		else begin
			count <= 0;
			rst <= BasicTypes_FALSE;
		end
	always @(*) rstStart = (rst && (count == 0) ? BasicTypes_TRUE : BasicTypes_FALSE);
endmodule

