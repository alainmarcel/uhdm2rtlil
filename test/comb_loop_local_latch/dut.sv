// Repro of CVA6 cva6_tlb.sv plru_replacement latch inference: ONE always_comb
// with TWO unrolled for-loops that BOTH declare `automatic` block-locals of the
// SAME names (idx_base/shift/new_index) — assigned conditionally in loop 1 and
// unconditionally in loop 2.  Each is a per-iteration SSA temp and must NOT
// infer a latch; but if the frontend promotes them to a single shared module
// wire, the conditional loop-1 assignments leave it undriven on the else path
// and proc infers a latch ("Latch inferred for signal shift/idx_base").
module comb_loop_local_latch #(
    parameter int unsigned N = 16
) (
    input  logic [N-1:0]       hit_i,
    input  logic               access_i,
    input  logic [2*(N-1)-1:0] tree_q,
    output logic [2*(N-1)-1:0] tree_o,
    output logic [N-1:0]       replace_en_o
);
  logic [2*(N-1)-1:0] tree_n;
  logic [N-1:0]       replace_en;
  assign tree_o = tree_n;
  assign replace_en_o = replace_en;
  always_comb begin
    tree_n = tree_q;
    for (int unsigned i = 0; i < N; i++) begin
      automatic int unsigned idx_base, shift, new_index;
      if (hit_i[i] & access_i) begin
        for (int unsigned lvl = 0; lvl < $clog2(N); lvl++) begin
          idx_base  = $unsigned((2 ** lvl) - 1);
          shift     = $clog2(N) - lvl;
          new_index = ~((i >> (shift - 1)) & 32'b1);
          tree_n[idx_base + (i >> shift)] = new_index[0];
        end
      end
    end
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
