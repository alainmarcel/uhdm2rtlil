// IEEE 1800-2023 11.4 / 11.8.1: the same operators on SIGNED operands.  Signed
// division truncates toward zero, % takes the sign of the dividend, >>> and
// >>>= sign-fill, and comparisons are signed.  (** is tested in
// lrm_power_variable_exponent.)
module dut(input  logic signed [7:0] a, b, input logic [2:0] sh,
           output logic signed [7:0] add, sub, mul, div, rem, neg, ashr2, ashl1,
           output logic signed [7:0] ashr, ashl, lshr, cashr,
           output logic lt, le, gt, ge, eq,
           output logic signed [15:0] wide_mul, wide_add,
           output logic signed [7:0] cond_mix,
           output logic [8:0] mix_us, output logic mix_cmp);
  // An odd divisor is never 0: x / 0 is X by 11.4.2, but a 2-state simulator
  // returns 0, so the co-sim could not check it.
  logic signed [7:0] bnz;
  assign bnz = {b[7:1], 1'b1};
  assign add = a + b;   assign sub = a - b;   assign mul = a * b;
  assign div = a / bnz; assign rem = a % bnz;   assign neg = -a;
  assign ashr2 = a >>> 2;                    // constant arithmetic shifts
  assign ashl1 = b <<< 1;
  assign ashr = a >>> sh;   assign ashl = a <<< sh;  assign lshr = a >> sh;
  assign lt = a < b; assign le = a <= b; assign gt = a > b; assign ge = a >= b;
  assign eq = a == b;
  assign wide_mul = a * b;                    // context width 16, sign-extended
  assign wide_add = a + b;
  assign cond_mix = sh[0] ? a : b >>> 1;
  assign mix_us   = a + 8'd1;                 // unsigned operand: unsigned add
  assign mix_cmp  = a < 8'd0;                 // unsigned compare: never true
  always_comb begin
    cashr = a;
    cashr >>>= sh;
  end
endmodule
