// YosysHQ/yosys#4363 (open): Spurious warnings "select out of bounds on signal" when there is no such thing ...
// https://github.com/YosysHQ/yosys/issues/4363
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): the SPRAM read data mem_do_w (never driven in the snippet, so rd_data was X) is looped back from mem_di_w; the computed part-select mapping the issue is about is unchanged

// ---- c0.sv
module top (
	output reg  [31:0] rd_data,
	input  wire [31:0] wr_data
);
	// Signals
	// -------
	wire [31:0] mem_do_w;
	reg  [31:0] mem_di_w;
	assign mem_do_w = mem_di_w;

	// Map input data to/from 16*NW bit words
	always @(*)
	begin : map
		integer n, x, o;

		// Map actual bits
		for (n=0; n<8; n=n+1)
		begin
			// Determine position
			x = n % 2;	// Which SPRAM
			o = n / 2;	// Which nibble inside that SPRAM

			mem_di_w[(16*x)+(4*o)+:4] =  wr_data[4*n+:4];
			rd_data[4*n+:4] = mem_do_w[(16*x)+(4*o)+:4];
		end
	end
endmodule

