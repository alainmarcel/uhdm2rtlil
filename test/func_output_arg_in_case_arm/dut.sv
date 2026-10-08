typedef struct packed { logic valid; logic [7:0] data; } op_t;

// A $unit-scope VOID function with an OUTPUT argument -- RSD's
// RISCV_DecodeMemOp / RISCV_DecodeBranch shape.
function automatic void EmitOps(
    output op_t [1:0] ops,
    input  logic [7:0] src
);
    ops[0].valid = 1'b1;
    ops[0].data  = src;
    ops[1].valid = 1'b0;
    ops[1].data  = ~src;
endfunction

module func_output_arg_in_case_arm (
    input  logic       sel,
    input  logic [7:0] src,
    output op_t [1:0]  ops,
    output logic       flag
);
    always_comb begin
        flag = 1'b0;
        case (sel)
            1'b1: EmitOps(ops, src);
            default: EmitOps(ops, 8'h00);
        endcase
        flag = 1'b1;
    end
endmodule
