// A NESTED void-function call whose output actual is a LOCAL of the enclosing
// inlined function, written by the callee from a CASE -- RSD Decoder's
//     RISCV_EmitFPOp: RISCV_DecodeFPOpFunct3(fpuCode, rv32fFunct3, ...);
//                     dstFP = !(fpuCode inside {...});
// Every FP instruction decoded as FC_ADD: the write-back of the inner call is
// an ACTION of the enclosing case, which RTLIL evaluates BEFORE that case's
// switches, so it copied the formal's pre-call X and the body's switch result
// reached nothing.  The write-back must thread its value for later reads.
typedef enum logic [6:0] { F7_FADD = 7'b0000000, F7_FSQRT = 7'b0101100, F7_FEQ_FLT_FLE = 7'b1010000 } F7;
typedef enum logic [2:0] { SGNJ = 3'b000, SGNJN = 3'b001, SGNJX = 3'b010 } SgnjF3;
typedef enum logic [2:0] { FEQ = 3'b010, FLT = 3'b001, FLE = 3'b000 } CmpF3;
typedef union packed { SgnjF3 sgnj; CmpF3 cmp; } F3;
typedef enum logic [4:0] { FC_ADD = 5'd0, FC_SQRT = 5'd4, FC_FEQ = 5'd13, FC_FLT = 5'd14, FC_FLE = 5'd15 } FPU_Code;
function automatic void DecodeF3(output FPU_Code code, input F3 f3, input F7 f7);
    case (f7)
        F7_FADD:  code = FC_ADD;
        F7_FSQRT: code = FC_SQRT;
        F7_FEQ_FLT_FLE: begin
            case (f3.cmp)
                FEQ: code = FC_FEQ;
                FLT: code = FC_FLT;
                FLE: code = FC_FLE;
                default: code = FC_FLE;
            endcase
        end
    endcase
endfunction
function automatic void EmitOp(output logic [4:0] res, input logic [31:0] insn);
    F3 f3; F7 f7; FPU_Code code;
    f3 = F3'(insn[14:12]);
    f7 = F7'(insn[31:25]);
    DecodeF3(code, f3, f7);
    res = code;
endfunction
module top(input logic [31:0] insn, output logic [4:0] out);
  always_comb begin
    EmitOp(out, insn);
  end
endmodule
