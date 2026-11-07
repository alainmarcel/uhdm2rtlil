// YosysHQ/yosys#2596 (closed): assertpmux pass generates wrong assertions for priority case
// https://github.com/YosysHQ/yosys/issues/2596
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test(input logic clk, output logic out1, out2, input logic [1:0] foo);

	assume property (foo == 3);

	always_ff @(posedge clk) begin
		priority case (1)
			foo == 3: out1 = 0;
			foo[0]:   out1 = 1;
			default;
			// should NOT assert, because first case (foo==3) matched and also because default case exists
		endcase

		priority case (foo)
			2: out2 = 0;
			1: out2 = 1;
			// should assert, because case foo==3 doesn't exist
		endcase
	end

endmodule

