// RSD Decoder: a module OUTPUT that is a PACKED array of structs is the output
// actual of void decode functions called in case arms; each function writes
// its output formal through a nested void call on an ELEMENT
// (`EmitInvalidOp(microOps[i])`) and an element assignment from a function
// return (`microOps[1] = ModifyMicroOp(...)`).
package pd2p;
  typedef struct packed { logic valid; logic [3:0] alu; logic [1:0] mid; logic undefined; } OpInfo;
  typedef struct packed { logic writePC; logic isCall; } InsnInfo;
endpackage
import pd2p::*;
function automatic void EmitInvalidOp(output OpInfo op);
    op = '0;
    op.valid = 1'b0;
endfunction
function automatic OpInfo ModifyMicroOp(input OpInfo src, input logic [1:0] mid, input logic last);
    OpInfo op;
    op = src;
    op.mid = mid;
    op.undefined = ~last;
    return op;
endfunction
function automatic void EmitAlu(output OpInfo opInfo, input logic [3:0] f);
    opInfo = '0;
    opInfo.alu = f;
    opInfo.valid = 1'b1;
endfunction
function automatic void DecodeA(output OpInfo [1:0] microOps, output InsnInfo insnInfo, input logic [7:0] insn);
    OpInfo intOp;
    logic [1:0] mid;
    EmitAlu(.opInfo(intOp), .f(insn[3:0]));
    mid = 0;
    for (int i = 0; i < 2; i++) begin
        EmitInvalidOp(microOps[i]);
    end
    microOps[1] = ModifyMicroOp(intOp, mid, 1'b1);
    mid += 1;
    insnInfo.writePC = 1'b0;
    insnInfo.isCall = insn[7];
endfunction
function automatic void DecodeB(output OpInfo [1:0] microOps, output InsnInfo insnInfo, input logic [7:0] insn);
    OpInfo intOp;
    EmitAlu(.opInfo(intOp), .f(insn[7:4]));
    for (int i = 0; i < 2; i++) begin
        EmitInvalidOp(microOps[i]);
    end
    microOps[0] = ModifyMicroOp(intOp, 2'd1, 1'b0);
    insnInfo.writePC = 1'b1;
    insnInfo.isCall = 1'b0;
endfunction
module void_func_call_in_case_arm (input logic [7:0] insn, output OpInfo [1:0] microOps, output InsnInfo insnInfo);
    always_comb begin
        insnInfo.writePC = 1'b0;
        insnInfo.isCall = 1'b0;
        case (insn[1:0])
            2'b00: DecodeA(microOps, insnInfo, insn);
            default: DecodeB(microOps, insnInfo, insn);
        endcase
    end
endmodule
