// YosysHQ/yosys#2896 (closed): `memory` pass bug on simple RAM
// https://github.com/YosysHQ/yosys/issues/2896
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module data_mem (
	clk_i,
	write_i,
	addr_i,
	wdata_i,
	wmask_i,
	rdata_o
);
	parameter unsigned [8:0] Width = 1;
	parameter unsigned [8:0] Depth = 4;
	localparam unsigned [8:0] Aw = $clog2(Depth);
	input wire clk_i;
	input wire write_i;
	input wire [Aw - 1:0] addr_i;
	input wire [Width - 1:0] wdata_i;
	input wire [Width - 1:0] wmask_i;
	output reg [Width - 1:0] rdata_o;
	reg [Width - 1:0] mem [Depth];
	always_ff @(posedge clk_i) begin
			if (write_i) begin
				reg unsigned [8:0] i;
				for (i = 0; i < Width; i = i + 1)
					if (wmask_i[i])
						mem[addr_i][i] <= wdata_i[i];
			end
			else
				rdata_o <= mem[addr_i];
    end
endmodule

