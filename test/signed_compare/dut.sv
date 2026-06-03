// Minimal reproduction of picorv32's alu_lts bug (dut.v:1237):
// `$signed(a) < $signed(b)` must be a SIGNED comparison.  The UHDM frontend
// dropped the operand signedness and computed it as UNSIGNED — making the
// signed less-than (lts) identical to the unsigned one (ltu), so SLTI/SLT/
// BLT/BGE decoded wrong.
module signed_compare (
	input  wire [31:0] a,
	input  wire [31:0] b,
	output wire        lts,   // signed   a < b
	output wire        ltu,   // unsigned a < b
	output wire        ges    // signed   a >= b
);
	assign lts = $signed(a) < $signed(b);
	assign ltu = a < b;
	assign ges = $signed(a) >= $signed(b);
endmodule
