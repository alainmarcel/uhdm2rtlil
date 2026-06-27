// Regression guard: nested function call with a struct-cast param arg and a
// $signed of a struct member — rp32 dec32's `imm_i_f(op32_i_t'(op))` where
// imm_i_f is `imm_t'($signed({op.imm_11_0}))`.  Exercises (a) struct-member
// reads of a function param in the inline path and (b) sys-func ($signed) args
// resolving the param base.
typedef logic signed [31:0] imm_t;
typedef struct packed { logic [19:0] rest; logic [11:0] imm; } i_t;
function automatic imm_t imm_f (i_t op);
  imm_f = imm_t'($signed({op.imm}));
endfunction
typedef struct packed { logic [31:0] ii; } d_t;
function automatic d_t mydec (logic [31:0] op);
  mydec.ii = imm_f(i_t'(op));
endfunction
module nested_cast_repro (input logic [31:0] instr, output logic [31:0] ii);
  d_t d; assign d = mydec(instr);
  assign ii = d.ii;
endmodule
