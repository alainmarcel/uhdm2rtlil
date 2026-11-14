// MikePopoloski/slang#1805 (closed): Slang allows non constant expressions in Verilog math functions
// https://github.com/MikePopoloski/slang/issues/1805
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
	reg [7:0] in = 8'h00;
	wire [7:0] out;

	test dut (.in(in), .out(out));
endmodule


module test(
	input  wire [7:0] in, 
	output wire [7:0] out           
);
	assign out = $ln(in);
endmodule

