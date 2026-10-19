// A void FUNCTION called as a statement with an ELEMENT of a packed array as
// its output actual, inside a for loop -- RSD Decoder's
//     for (int i = 0; i < MICRO_OP_MAX_NUM; i++) EmitInvalidOp(microOps[i]);
//     microOps[1] = ModifyMicroOp(opInfo, mid, FALSE, TRUE);
// The assigned-signal scanner skipped func_call statements (only task calls,
// and only a bare ref_obj actual), so the loop's element writes had no temp;
// the output write-back then landed on the RAW wire, which fought the sync
// update of the one element the plain assignment registered: microOps[1]
// read as all zero (the illegal instruction's envCode was lost).
typedef enum logic [3:0] { ENV_CALL = 1, ENV_BREAK = 2, ENV_INSN_ILLEGAL = 3, ENV_INSN_VIOLATION = 5, ENV_MRET = 6 } ENV_Code;
typedef struct packed { logic isFP; logic [4:0] regNum; } LRegNumPath;
typedef struct packed {
    LRegNumPath dstRegNum, srcRegNumA, srcRegNumB;
    ENV_Code envCode;
    logic isEnv;
    logic [18:0] padding;
    logic [11:0] imm;
} SystemMicroOpOperand;
typedef struct packed { logic [3:0] a; logic [49:0] b; } OtherOperand;
typedef union packed { OtherOperand other; SystemMicroOpOperand systemOp; } MicroOpOperand;
typedef struct packed {
    logic [2:0] mopType;
    MicroOpOperand operand;
    logic writeReg;
    logic valid;
    logic [1:0] mid;
} OpInfo;
function automatic void EmitIllegalOp(output OpInfo opInfo, input logic illegalPC);
    SystemMicroOpOperand systemOp;
    systemOp.dstRegNum.isFP = 1'b0; systemOp.srcRegNumA.isFP = 1'b0; systemOp.srcRegNumB.isFP = 1'b0;
    systemOp.dstRegNum.regNum = '0; systemOp.srcRegNumA.regNum = '0; systemOp.srcRegNumB.regNum = '0;
    systemOp.isEnv = 1'b1;
    systemOp.padding = '0;
    systemOp.imm = '0;
    systemOp.envCode = illegalPC ? ENV_INSN_VIOLATION : ENV_INSN_ILLEGAL;
    opInfo.mopType = 3'd2;
    opInfo.operand.systemOp = systemOp;
    opInfo.writeReg = 1'b0;
    opInfo.valid = 1'b1;
    opInfo.mid = '0;
endfunction
function automatic void EmitInvalidOp(output OpInfo op);
    op = '0;
    op.valid = 1'b0;
endfunction
function automatic OpInfo ModifyMicroOp(input OpInfo src, input logic [1:0] mid);
    OpInfo op;
    op = src; op.mid = mid;
    return op;
endfunction
module top(input logic illegalPC, sel, output OpInfo [2:0] microOps);
  always_comb begin
    OpInfo opInfo;
    for (int i = 0; i < 3; i++) EmitInvalidOp(microOps[i]);
    EmitIllegalOp(opInfo, illegalPC);
    microOps[1] = ModifyMicroOp(opInfo, 2'd0);
  end
endmodule
