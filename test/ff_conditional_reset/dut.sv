// Reproducer for CVA6 cva6_fifo_v3 synth error "Async reset yields non-constant
// value 32'mmm..m": a register (`qft`) in an async-reset always_ff is assigned
// ONLY under a false compile-time guard (`if (COND)`) in EVERY branch, so it is
// never actually assigned.  The frontend still creates an async-reset FF for it
// with an undefined/marker reset value; it should instead leave it undriven (no
// async-reset FF), matching slang/Verilog.
module ff_conditional_reset #(
    parameter bit COND = 1'b0
) (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic [31:0] d_i,
    output logic [31:0] q_o,
    output logic [31:0] qft_o
);
  logic [31:0] q, qft;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      q <= '0;
      if (COND) qft <= '0;
    end else begin
      q <= d_i;
      if (COND) qft <= d_i;    // qft assigned ONLY under COND (false) -> never
    end
  end
  assign q_o = q;
  assign qft_o = qft;
endmodule
