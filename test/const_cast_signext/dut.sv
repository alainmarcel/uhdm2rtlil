// Compile-time evaluation of type/size casts inside a function (RISC-V decoder
// immediate-extraction pattern `imm_t'($signed({op.field}))`).  When the
// function is folded with constant arguments, the const evaluator must handle:
//   - the type cast  T'(...)          (vpiCastOp)
//   - $signed / $unsigned             (sys_func_call)
//   - a struct-member read op.field   (hier_path on a local variable)
// Previously the cast was unsupported and the function folded to all-X.
module const_cast_signext (
  output logic [31:0] imm_i,   // sign-extended  0xFFF -> 0xFFFFFFFF
  output logic [31:0] imm_neg, // sign-extended  0x800 -> 0xFFFFF800
  output logic [31:0] imm_u,   // zero-extended  0x800 -> 0x00000800
  output logic [7:0]  imm_sz   // size cast 8'(0x800) -> 0x00
);
  typedef logic signed [31:0] imm_t;
  typedef struct packed { logic [19:0] hi; logic [11:0] f; } op_t;

  function automatic imm_t         sext (op_t op); sext = imm_t'($signed({op.f}));  endfunction
  function automatic logic [31:0]  uext (op_t op); uext = 32'($unsigned(op.f));     endfunction
  function automatic logic [7:0]   szc  (op_t op); szc  = 8'(op.f);                 endfunction

  localparam op_t OP_F = '{hi:'0, f: 12'hFFF};
  localparam op_t OP_8 = '{hi:'0, f: 12'h800};

  assign imm_i   = sext(OP_F);
  assign imm_neg = sext(OP_8);
  assign imm_u   = uext(OP_8);
  assign imm_sz  = szc (OP_8);
endmodule
