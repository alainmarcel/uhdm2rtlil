// A block-local `automatic` reduction accumulator inside a combinational loop,
// updated under BOTH arms of a runtime `if`:
//   en = 1'b1; for (j) if (sel) en &= x; else en &= ~x;  out = en;
// The accumulator is written under its PRIVATE scoped wire name
// (`$unnamed_block$N.en`) but read under its bare name (`en`).  When the update
// happens inside an if/else, thread_comb_if merges the two arms into a mux; the
// merged value must be recorded — and the pre-if value looked up — under the
// bare alias, otherwise every iteration re-reads the stale init `en = 1` and the
// reduction collapses.  This is the CVA6 cva6_tlb.sv plru_replacement shape.
module comb_reduction_accumulator #(parameter int unsigned N = 4, parameter int unsigned M = 4) (
    input  logic [N-1:0][M-1:0] data_i,
    input  logic [N-1:0][M-1:0] sel_i,
    output logic [N-1:0]        en_o
);
  always_comb begin
    for (int unsigned i = 0; i < N; i++) begin
      automatic logic en;
      en = 1'b1;
      for (int unsigned j = 0; j < M; j++) begin
        if (sel_i[i][j]) en &= data_i[i][j];
        else             en &= ~data_i[i][j];
      end
      en_o[i] = en;
    end
  end
endmodule
