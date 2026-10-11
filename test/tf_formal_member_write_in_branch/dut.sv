// RSD Decoder (RISCV_EmitMiscMemOp): a member write on a void function's
// OUTPUT FORMAL inside an if/else arm was dropped, while the unconditional
// member writes of the same function all landed -- `opInfo.undefined` was
// never driven.  That is Decoder's 31 "never assigned" bits and twice that in
// PreDecodeStage, which holds two decoders.
typedef struct packed { logic [2:0] cond; logic [3:0] payload; logic valid; logic undefined; logic serialized; } op_t;
function automatic void Emit(output op_t opInfo, input logic [3:0] p, input logic fence);
  opInfo.cond = 3'b010;
  opInfo.payload = p;
  opInfo.valid = 1'b1;
  if (fence) begin
    opInfo.undefined = 1'b0;
  end
  else begin
    opInfo.undefined = 1'b1;
  end
  opInfo.serialized = 1'b1;
endfunction
module tf_formal_member_write_in_branch(input logic [3:0] p, input logic fence, output logic [9:0] y);
  op_t op;
  always_comb begin
    Emit(op, p, fence);
    y = op;
  end
endmodule
