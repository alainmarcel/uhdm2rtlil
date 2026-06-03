// Minimal reproduction of picorv32's shift bug (dut.v:1833-1843):
// constant-amount shifts used in the SLLI/SRLI/SRAI two-stage shifter.
module const_ashift (
	input  wire [31:0] a,
	output wire [31:0] shl4,   // a << 4
	output wire [31:0] shr4,   // a >> 4   (logical)
	output wire [31:0] asr4,   // $signed(a) >>> 4  (arithmetic)
	output wire [31:0] shl1,
	output wire [31:0] shr1,
	output wire [31:0] asr1
);
	assign shl4 = a << 4;
	assign shr4 = a >> 4;
	assign asr4 = $signed(a) >>> 4;
	assign shl1 = a << 1;
	assign shr1 = a >> 1;
	assign asr1 = $signed(a) >>> 1;
endmodule
