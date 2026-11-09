// YosysHQ/yosys#2465 (open): SMT2 Backend Treats Non-POT-Sized Memories as next higher POT
// https://github.com/YosysHQ/yosys/issues/2465
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): output dout observes the memory read data (the snippet had no output)

// ---- c0.sv
module top (
	input clk,
	output logic [3:0] dout
);
assign dout = data_out;

logic [3:0] mem [0:8];
logic write;
logic [8:0] addr_in, addr_out;
logic [3:0] data_in;
wire [3:0] data_out = mem[addr_out];

always @(posedge clk) begin
	if (write)
		mem[addr_in] <= data_in;
end

logic [7:0] cycle = 0;
always_ff @(posedge clk) begin
	if (cycle != '1)
		cycle <= cycle + 1;
end

always_comb begin
	write = '0;
	data_in = '0;
	addr_in = '0;
	addr_out = '0;
	case (cycle)
		0: begin
			write = 1;
			addr_in = 12;
			data_in = 15;
		end
		1: begin
			addr_out = 12;
			assert(data_out == 15);
		end
		2: begin
			addr_out = 13;
			assert(data_out == 15);
		end
	endcase
end

endmodule

