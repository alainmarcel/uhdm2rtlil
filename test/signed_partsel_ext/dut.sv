// Minimal reproduction of picorv32's decoded_imm sign-extension bug
// (dut.v:1116-1129).  Inside a (* parallel_case *) case(1'b1), a branch
// assigns `$signed()` of a narrow part-select / concat to a 32-bit reg.
// That value must SIGN-extend to 32 bits; the UHDM frontend zero-extends
// the $signed branch values of a case (the single-assignment form works,
// so the bug is specific to the case/mux branch extension).
//
// Combinational + directly-observable so the difference isn't masked by
// FF/don't-care handling in the equivalence flow.
module signed_partsel_ext (
	input  wire [31:0] insn,
	input  wire [31:0] imm_j,      // pre-decoded (unsigned) J immediate
	input  wire [4:0]  sel,
	output reg  [31:0] decoded_imm
);
	wire is_jal = sel[0];
	wire is_lui = sel[1];
	wire is_i   = sel[2];   // jalr / load / alu-imm
	wire is_b   = sel[3];   // branch
	wire is_s   = sel[4];   // store

	always @* begin
		(* parallel_case *)
		case (1'b1)
			is_jal: decoded_imm = imm_j;
			is_lui: decoded_imm = insn[31:12] << 12;
			is_i:   decoded_imm = $signed(insn[31:20]);
			is_b:   decoded_imm = $signed({insn[31], insn[7], insn[30:25], insn[11:8], 1'b0});
			is_s:   decoded_imm = $signed({insn[31:25], insn[11:7]});
			default: decoded_imm = 32'h0;
		endcase
	end
endmodule
