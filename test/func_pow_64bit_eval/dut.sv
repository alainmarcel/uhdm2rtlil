// A constant function whose modulus is `longint unsigned M = 2**32;` (the
// LCG common_cells cc_sub_per_hash uses for its xor-stage tables).  The
// compile-time evaluator's `**` returned a 32-bit result, so 2**32 folded
// to 0, the following `% M` was a "Modulus by zero" and every table entry
// came out 0.  A power result that does not fit 32 bits is now a 64-bit
// value; narrower results keep the 32-bit form.
module func_pow_64bit_eval #(
  parameter int unsigned Seed = 7
) (
  input  logic [31:0] data_i,
  output logic [31:0] y_o
);
  assign y_o = lcg(Seed) ^ data_i;

  // second iterate for seed 7: 0xE9DAB1D1
  function automatic logic [31:0] lcg(input int unsigned seed);
    longint unsigned A = 1664525;
    longint unsigned C = 1013904223;
    longint unsigned M = 2**32;
    longint unsigned r = (A * seed + C) % M;
    r = (A * r + C) % M;
    return r[31:0];
  endfunction
endmodule
