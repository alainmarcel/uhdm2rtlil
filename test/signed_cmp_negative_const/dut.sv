// A relational comparison against a NEGATIVE constant folded as UNSIGNED.
//
// The constant-fold path in import_operation called
//   RTLIL::const_ge(a, b, false, false, 1)
// with both signedness flags hard-coded false, so `integer w2 = 0; w2 >= -4`
// folded as `0 >= 32'hFFFFFFFC` -- false.  Per LRM 11.8.1 a relational
// comparison is signed when BOTH operands are, and `integer` is signed.
//
// Outside a loop the comparison is not const-folded and was always right,
// which is why this went unnoticed; inside an unrolled loop the fold applies
// to every iteration, so the error is silent and total -- every element takes
// the same wrong branch.
//
// In the wild: CORE-V Wally's fdivsqrtuslc4 builds its 1024-entry quotient
// selection table from chains of `w2 >= -4` / `w2 >= -13`, so EVERY entry fell
// through to the final else.  Its only output, udigit, was wrong on 120 of 301
// co-sim cycles.  After the fix that module is proven equivalent with a clean
// co-sim.
//
// `pos` and `direct` are the controls that always worked: a positive right
// hand side, and the loop variable compared without an intermediate.
module signed_cmp_negative_const (
  output logic [15:0] neg_rhs,   // was all-zero
  output logic [15:0] pos_rhs,   // control
  output logic [15:0] direct,    // control
  output logic [15:0] folded     // the two's-complement fold from the wild case
);
  always_comb begin
    integer w, w2;
    for (w = 0; w < 16; w++) begin
      w2          = w;
      neg_rhs[w]  = (w2 >= -4);
      pos_rhs[w]  = (w2 >= 8);
      direct[w]   = (w >= 8);
      w2          = w - 16*(w >= 8);   // 0..7 then -8..-1
      folded[w]   = (w2 >= -4);
    end
  end
endmodule
