// CVA6 pmp.sv repro (adjudicated against a hand-written break-free reference
// under iverilog — iverilog itself cannot parse `break`):
// a comb `for` loop with `break`, followed by a test on the LOOP VARIABLE
// (`if (i == N)` = "no iteration matched").  The importer unrolled the loop
// but drove the loop variable to the STATIC final value N, so the post-loop
// "nothing matched" fallback fired unconditionally — CVA6 pmp's allow_o was
// always the no-match value, which flipped cva6_ptw's allow_access.
// Fix: a per-iteration break flag (set by the vpiBreak handler under the
// branch conditions reaching it) feeding a first-break-index priority mux.
module loop_break_index #(
  parameter int N = 4
)(
  input  logic [N-1:0] match,
  input  logic [N-1:0] allow,
  input  logic         is_m,
  output logic         allow_o,
  output logic [31:0]  idx_o
);
  always_comb begin
    int i;
    allow_o = 1'b0;
    for (i = 0; i < N; i++) begin
      if (match[i]) begin
        allow_o = allow[i];
        break;
      end
    end
    idx_o = i;              // first-break index, or N when nothing matched
    if (i == N) allow_o = is_m;
  end
endmodule
