// Minimal repro of kmac_msgfifo's foreach over an unpacked array in always_comb
// / always_ff (vpiForeachStmt, UHDM type 675) — the UHDM frontend dropped the
// loop body ("Unsupported statement type in comb context: 675"), so the reduced
// output was wrong.
module foreach_comb #(parameter int N = 3) (
  input  logic        clk_i, rst_ni,
  input  logic [N-1:0] set_i,
  input  logic        e_i [N],
  output logic        all_o,
  output logic [N-1:0] q_o
);
  // always_comb reduction over an unpacked array via foreach
  always_comb begin
    all_o = 1'b1;
    foreach (e_i[i]) begin
      all_o &= e_i[i];
    end
  end
  // always_ff foreach with a conditional per-element write
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) q_o <= '0;
    else foreach (set_i[i]) begin
      if (set_i[i]) q_o[i] <= 1'b1;
    end
  end
endmodule
