module priority_memory (
	clk, wren_a, rden_a, addr_a, wdata_a, rdata_a,
	wren_b, rden_b, addr_b, wdata_b, rdata_b
	);

	parameter ABITS = 4;  // Reduced from 12 to 4 (16 locations instead of 4096)
	parameter WIDTH = 8;  // Reduced from 72 to 8

	input clk;
	input wren_a, rden_a, wren_b, rden_b;
	input [ABITS-1:0] addr_a, addr_b;
	input [WIDTH-1:0] wdata_a, wdata_b;
	output reg [WIDTH-1:0] rdata_a, rdata_b;

	reg [WIDTH-1:0] mem [0:2**ABITS-1];

	integer i;
	initial begin
		rdata_a <= 'h0;
		rdata_b <= 'h0;
	end

	always @(posedge clk) begin
		// A port
		if (wren_a)
			mem[addr_a] <= wdata_a;
		else if (rden_a)
			rdata_a <= mem[addr_a];

		// B port
		if (wren_b)
			mem[addr_b] <= wdata_b;
		else if (rden_b)
			if (wren_a && addr_a == addr_b)
				rdata_b <= wdata_a;
			else
				rdata_b <= mem[addr_b];
	end
endmodule