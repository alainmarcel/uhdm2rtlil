// For-loop-variable computed indices on the LHS: a bit-select `sig[b*2+0]` and
// an indexed part-select `vld[b*2 +: 2]`.  Before the offset_is_dynamic guard,
// extract_assigned_signals imported the index/base (`b*2`) to test const-ness
// BEFORE the loop was unrolled, fabricating an undriven `\g.b` wire + dead
// `$mul` (the ibex_alu g_alu_rvb `.b`/`.h` residual the opt-check flags).  The
// writes themselves are correct; this just checks the design is X-free/driven.
module loopvar_index_no_stray(input logic [3:0] d, output logic [7:0] sel,
                              output logic [7:0] vld);
  if (1) begin : g
    always_comb begin
      sel = '0;
      vld = '0;
      for (int b = 0; b < 4; b++) begin
        sel[b*2 + 0] = d[b];
        sel[b*2 + 1] = ~d[b];
        vld[b*2 +: 2] = {2{d[b]}};
      end
    end
  end
endmodule
