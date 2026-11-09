// YosysHQ/yosys#699 (closed): Feature request: support for named assertions
// https://github.com/YosysHQ/yosys/issues/699
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): the counter X is observable on a new output q (the module had no output); the named assertions are unchanged

// ---- b0.sv
module counter(clk, en, q);
	output [3:0] q;
	input clk;
	input en;
	reg [3:0] X;
	assign q = X;
	initial begin
		X = 4'd1;
	end
	always @(posedge clk) begin
		X <= en ? ( (X == 4'd15) ? 4'd1 : (X + 4'd1) ) : X ;
	end
	property1: assert property ( X != 4'd0 );
	property2: assert property ( X > 4'd0 );
endmodule

