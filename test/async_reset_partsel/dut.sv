// Minimal reproduction: an async-reset always_ff whose LHS is a PART-SELECT.
// The async-reset path skipped part-selects, so no flip-flop was inferred and
// the block collapsed to a combinational mux.  Covers a plain part-select and
// (via the generate loop) an indexed part-select with a per-block slice.
module async_reset_partsel (
	input  wire        clk,
	input  wire        rst_n,
	input  wire [7:0]  u,
	output reg  [7:0]  q_lo,     // plain part-select slice
	output reg  [31:0] q_wide    // four indexed-part-select slices
);
	always_ff @(posedge clk or negedge rst_n)
		if (!rst_n) q_lo[7:0] <= '0;
		else        q_lo[7:0] <= u;

	genvar i;
	generate
		for (i = 0; i < 4; i++) begin : g
			always_ff @(posedge clk or negedge rst_n)
				if (!rst_n) q_wide[i*8 +: 8] <= '0;
				else        q_wide[i*8 +: 8] <= u;
		end
	endgenerate
endmodule
