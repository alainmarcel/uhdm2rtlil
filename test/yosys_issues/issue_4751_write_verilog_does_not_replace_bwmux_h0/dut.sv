// YosysHQ/yosys#4751 (open): `write_verilog` does not replace bwmux instances
// https://github.com/YosysHQ/yosys/issues/4751
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top;
reg x, b;
reg [2:0] a;
reg [2:0] out;
always_comb begin
	out = a;
	out[x] = b;
end
endmodule

