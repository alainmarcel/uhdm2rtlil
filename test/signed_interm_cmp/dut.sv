// Signedness of an INTERMEDIATE operation result feeding a wider signed
// context — fpnew_fma's normalization guard:
//   if (exponent_product_q - leading_zero_count_sgn + 1 >= 0)
// The signed 10-bit subtraction result is an anonymous wire the importer
// never marked signed, so the `+ 1` zero-extended it into a 64-bit add and
// -1 compared as 1023: the subnormal branch was never taken (fpnew_fma
// result_o wrong on denormals).  Also covers the unsuffixed decimal literal
// (`1`, signed per LRM 5.7.1) as an add operand.
module signed_interm_cmp (
    input  logic signed [9:0] p,
    input  logic        [4:0] lzc,
    output logic o_cmp,
    output logic signed [9:0] o_sum
);
  logic signed [5:0] z;
  assign z = $signed({1'b0, lzc});
  assign o_cmp = (p - z + 1 >= 0);
  assign o_sum = p - z + 1;
endmodule
