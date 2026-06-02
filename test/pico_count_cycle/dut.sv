// Minimal reproduction of picorv32 count_cycle / count_instr equivalence
// failure.  Mirrors the always @(posedge clk) block structure of
// test/functional_picorv32/dut.v (multiple statements + an `if (!resetn)`
// reset block) so the importer takes the same always_ff comb-body path
// (temp wire `$0\count_cycle`, base-slice collapse) as the full core.
module pico_count_cycle #(
	parameter [0:0] ENABLE_COUNTERS   = 1,
	parameter [0:0] ENABLE_COUNTERS64 = 1
) (
	input  wire        clk,
	input  wire        resetn,
	input  wire        do_count,
	output reg  [63:0] count_cycle,
	output reg  [63:0] count_instr
);
	always @(posedge clk) begin
		// extra statement so the body is a multi-stmt begin block, not a
		// lone if (forces the comb-body path, not is_simple_if_else)
		if (ENABLE_COUNTERS) begin
			count_cycle <= resetn ? count_cycle + 1 : 0;
			if (!ENABLE_COUNTERS64) count_cycle[63:32] <= 0;
		end else begin
			count_cycle <= 'bx;
			count_instr <= 'bx;
		end

		if (do_count) begin
			if (ENABLE_COUNTERS) begin
				count_instr <= count_instr + 1;
				if (!ENABLE_COUNTERS64) count_instr[63:32] <= 0;
			end
		end

		if (!resetn) begin
			if (ENABLE_COUNTERS)
				count_instr <= 0;
		end
	end
endmodule
