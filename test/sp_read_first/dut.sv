module sp_read_first (clk, wren_a, rden_a, addr_a, wdata_a, rdata_a);

	parameter ABITS = 4;  // Reduced from 12 to 4 (16 locations instead of 4096)
	parameter WIDTH = 8;  // Reduced from 72 to 8

	input clk;
	input wren_a, rden_a;
	input [ABITS-1:0] addr_a;
	input [WIDTH-1:0] wdata_a;
	output reg [WIDTH-1:0] rdata_a;

	reg [WIDTH-1:0] mem [0:2**ABITS-1];

	integer i;
	initial begin
		rdata_a <= 'h0;
	end

	always @(posedge clk) begin
		// A port
		if (wren_a)
			mem[addr_a] <= wdata_a;
		if (rden_a)
			rdata_a <= mem[addr_a];
	end
endmodule