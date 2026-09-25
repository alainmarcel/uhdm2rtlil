// A constant function doing 64-bit (`longint unsigned`) arithmetic: the
// multiplicative LCG common_cells cc_sub_per_hash uses to generate its
// permutation tables.  The compile-time evaluator ran every + - * / % at
// 32 bits (`as_int`), so `A * seed + C` wrapped and `% M` then divided a
// NEGATIVE int: the result was 0x8000_0E29 instead of 0x0000_0CD8.
// Arithmetic now runs at the widest operand's width (up to 64 bits).
module func_longint_lcg_eval #(
  parameter int unsigned Seed = 7
) (
  input  logic [31:0] data_i,
  output logic [31:0] y_o
);
  assign y_o = lcg(Seed) ^ data_i;

  function automatic logic [31:0] lcg(input int unsigned seed);
    longint unsigned A = 2147483629;
    longint unsigned C = 2147483587;
    longint unsigned M = 2**31 - 1;
    longint unsigned r = (A * seed + C) % M;
    r = (A * r + C) % M;
    return r[31:0];
  endfunction
endmodule
