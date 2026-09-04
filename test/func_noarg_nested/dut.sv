package fnn_pk;
  typedef enum logic [6:0] { OPCODE_OP_IMM = 7'h13, OPCODE_JALR = 7'h67 } opcode_e;
endpackage
module func_noarg_nested import fnn_pk::*; (
  input  logic       sel,
  output logic [31:0] o
);
  function automatic logic [31:0] mv_reg(input logic [4:0] src, input logic [4:0] dst);
    logic [31:0] instr;
    instr[ 6: 0] = OPCODE_OP_IMM;
    instr[11: 7] = dst;
    instr[14:12] = 3'b000;
    instr[19:15] = src;
    instr[31:20] = 12'd0;
    return instr;
  endfunction

  function automatic logic [31:0] zero_a0();
    return mv_reg(.src(5'd0), .dst(5'd10));
  endfunction

  function automatic logic [31:0] ret_ra();
    logic [31:0] instr;
    instr[ 6: 0] = OPCODE_JALR;
    instr[11: 7] = 5'd0;
    instr[14:12] = 3'b000;
    instr[19:15] = 5'd1;
    instr[31:20] = 12'd0;
    return instr;
  endfunction

  always_comb begin
    if (sel) o = zero_a0();
    else     o = ret_ra();
  end
endmodule
