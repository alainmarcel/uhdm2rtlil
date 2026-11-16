// IEEE 1800-2023 11.4.3 / Table 11-4: the power operator, with VARIABLE and
// constant exponents.  For a signed exponent that is negative the result is 0, except
// that a base of 1 gives 1, and a base of -1 gives 1 or -1 for an even or odd
// exponent; 0 ** negative is X.  An unsigned exponent is never negative.
// Both readers emit a $pow cell, which neither the SAT miter nor a value proof
// can model, so this test relies on the co-sim.
module dut(input  logic [7:0] a, input logic [2:0] ue,
           input  logic signed [7:0] b, input logic signed [2:0] se,
           output logic [7:0] upow, output logic signed [7:0] spow,
           output logic signed [7:0] spow_u, spow_c, output logic [7:0] upow_c);
  assign upow   = a ** ue;
  assign upow_c = a ** 3;             // constant exponent
  assign spow_c = b ** 2'sd2;         // 2'sd2 is -2 (2-bit signed): 0, 1 or -1
  assign spow   = b ** se;            // signed base, signed exponent
  assign spow_u = b ** ue;            // signed base, unsigned exponent
endmodule
