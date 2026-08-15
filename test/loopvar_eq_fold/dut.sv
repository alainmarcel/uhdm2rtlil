// CVA6 cva6_ptw repro (adjudicated against iverilog, NOT just the miter):
// constant folding of `==` / `!=` used RTLIL::Const::operator==, which
// compares the bit-vector INCLUDING ITS WIDTH.  An unrolled loop variable
// folds to a 32-bit constant while an integer literal arrives 64-bit, so
// `y == 0` inside `for (int unsigned y …)` was FALSE on every iteration —
// silently dropping the y==0 arm.  `<` was unaffected (it already used the
// value-semantics const_lt helper), which is what made this so quiet.
// In cva6_ptw: `shared_tlb_update_o.is_page[x][y] = y == 0 ? (…) : 1'b0;`
module loopvar_eq_fold (
  input  logic       a,
  output logic [1:0] o_eq,     // (y == 0)
  output logic [1:0] o_neq,    // (y != 0)
  output logic [1:0] o_tern,   // y == 0 ? a : 1'b0
  output logic [1:0] o_int,    // signed int loop var
  output logic [1:0] o_lt      // (y < 1) — the control that always worked
);
  always_comb begin
    o_eq = '0; o_neq = '0; o_tern = '0; o_int = '0; o_lt = '0;
    for (int unsigned y = 0; y < 2; y++) begin
      o_eq[y]   = (y == 0);
      o_neq[y]  = (y != 0);
      o_tern[y] = y == 0 ? a : 1'b0;
      o_lt[y]   = (y < 1);
    end
    for (int y2 = 0; y2 < 2; y2++)
      o_int[y2] = (y2 == 0);
  end
endmodule
