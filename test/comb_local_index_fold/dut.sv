// A block-local `automatic` temp in a combinational always block, assigned a
// CONSTANT loop-var expression and then used as a bit-select INDEX:
//   automatic int idx; idx = (2**lvl)-1+i; r[idx] = 1'b1;
// The index must fold to a constant so `r[idx]` is a STATIC bit-write.  Before
// the fix the block-local temp value was recorded under its PRIVATE scoped wire
// name (`$unnamed_block$N.idx`) but never under the bare read name (`idx`), so
// the index stayed a runtime wire and the write degraded to a dynamic $shiftx —
// and in a loop that produced conflicting mux drivers (opt_muxtree multi-driver
// abort) plus spurious latches.  Mirrors CVA6 cva6_tlb.sv plru_replacement's
// `plru_tree_n[idx_base + (i>>shift)] = …`.
module comb_local_index_fold #(parameter int N = 4) (
    input  logic [N-1:0]   hit_i,
    output logic [2*N-1:0] out_o
);
  logic [2*N-1:0] r;
  assign out_o = r;
  always_comb begin
    r = '0;
    for (int unsigned i = 0; i < N; i++) begin
      automatic int unsigned idx;
      if (hit_i[i]) begin
        for (int unsigned lvl = 0; lvl < 2; lvl++) begin
          idx = (2**lvl) - 1 + i;
          r[idx] = 1'b1;
        end
      end
    end
  end
endmodule
