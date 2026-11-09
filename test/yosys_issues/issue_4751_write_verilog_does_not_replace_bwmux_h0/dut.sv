// YosysHQ/yosys#4751 (open): `write_verilog` does not replace bwmux instances
// https://github.com/YosysHQ/yosys/issues/4751
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): x, b, a are inputs and out the output (the snippet had no ports, so everything was undriven); the dynamic bit write out[x] = b is unchanged

// ---- b0.sv
module top(input logic x, b, input logic [2:0] a, output reg [2:0] out);
always_comb begin
	out = a;
	out[x] = b;
end
endmodule

