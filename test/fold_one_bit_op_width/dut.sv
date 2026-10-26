// A reduction (or logical / relational) operator over PARAMETERS is folded by
// Surelog's ExprEval before the reader sees it, and the folded constant comes
// back sized as a 64-bit integer -- the operator's result is ONE bit by
// definition (LRM 11.6.1).  Inside a concatenation that misplaces every other
// operand:
//
//     casez ({next_instr_is_32bit, |EXTENSION_ZCMP, next_instr[15:0]})
//
// in Hazard3's frontend compared an 81-bit selector against 18-bit patterns,
// so the 32-bit-instruction arm never matched and every 32-bit rs1 predecode
// fell to the default: 245 co-simulated divergences on hazard3_frontend.  The
// same concat on the right-hand side of an assign was silently TRUNCATED to
// the target width, which happened to keep the right low bits.
module dut #(parameter EXT = 1, parameter W = 4) (
  input        a,
  input  [1:0] b,
  output [3:0] y,
  output reg [3:0] z,
  output [4:0] w
);
  assign y = {a, |EXT, b};
  // every operator class the fold must keep at one bit (&EXT over the
  // 32-bit integer parameter is 0: the unsized parameter is an integer)
  assign w = {&EXT, !EXT, EXT == 1, EXT > W, W >= 4 && EXT};
  always @(*) begin
    case ({a, |EXT, b})
      4'b1_1_00: z = 4'd1;
      4'b0_1_11: z = 4'd2;
      default:   z = 4'd0;
    endcase
  end
endmodule
