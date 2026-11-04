// `$signed(a) - $signed(b) - c`: the trailing UNSIGNED operand makes the
// whole expression unsigned (LRM 11.8.1), so the inner signed subtract
// zero-extends its operands to the context width.  spatz_simd_lane's
// subtractor_result = $signed(arith_op2) - $signed(arith_op1) - carry_i
// lost its borrow bit (VMSBC) because the inner subtract sign-extended.
// The matching add chain was already right; it is here as the control.
module dut(input logic [7:0] a, input logic [7:0] b, input logic c, input logic v,
           output logic [8:0] sub_v, output logic [8:0] sub_c, output logic [8:0] sub_ss,
           output logic [8:0] add_v, output logic [7:0] borrow);
  assign sub_v  = v ? $signed(a) - $signed(b) - c : '0;
  assign sub_c  = $signed(a) - $signed(b) - c;
  assign sub_ss = $signed(a) - $signed(b);          // fully signed: sign-extends
  assign add_v  = v ? $signed(a) + $signed(b) + c : '0;
  assign borrow = 8'(sub_v[8]);
endmodule
