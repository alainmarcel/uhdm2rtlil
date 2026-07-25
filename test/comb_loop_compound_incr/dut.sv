// A combinational for-loop whose increment uses the COMPOUND form `i += 1`
// (as opposed to `i++` or `i = i + 1`).  In UHDM the compound assignment carries
// the arithmetic operator on the *assignment* node (VpiOpType == vpiAddOp) with a
// bare constant Rhs, whereas the loop unroller only recognised `i++`
// (vpiPostIncOp) and `i = i + N` (an operation Rhs).  The `i += 1` form fell
// through to `can_unroll = false`, so the ENTIRE loop body was silently dropped
// (output collapsed to a constant / X).  Mirrors CVA6 cva6_tlb.sv
// plru_replacement's outer `for (int i = 0; i < N; i += 1)` reduction loop.
module comb_loop_compound_incr #(parameter int unsigned N = 16) (
    input  logic [2*(N-1)-1:0] tree_q,
    output logic [N-1:0]       replace_en_o
);
  logic [N-1:0] replace_en;
  assign replace_en_o = replace_en;
  always_comb begin
    for (int unsigned i = 0; i < N; i += 1) begin
      automatic logic en;
      automatic int unsigned idx_base, shift, new_index;
      en = 1'b1;
      for (int unsigned lvl = 0; lvl < $clog2(N); lvl++) begin
        idx_base  = $unsigned((2 ** lvl) - 1);
        shift     = $clog2(N) - lvl;
        new_index = (i >> (shift - 1)) & 32'b1;
        if (new_index[0]) en &= tree_q[idx_base + (i >> shift)];
        else              en &= ~tree_q[idx_base + (i >> shift)];
      end
      replace_en[i] = en;
    end
  end
endmodule
