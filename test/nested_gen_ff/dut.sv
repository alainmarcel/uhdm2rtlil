// A no-reset always_ff inside a NESTED generate scope (gen-if in gen-if).
// The simple-if always_ff path looked its assigned signals up by BARE name,
// missed the gen-scope-prefixed wires, and silently skipped both the $0 temp
// wires and the sync updates -- proc then collapsed the whole register bank
// into a combinational passthrough (Pavona ibex_wb_stage wb_*_q).
module nested_gen_ff #(
  parameter bit UseStage = 1'b1,
  parameter bit ResetAll = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        en_i,
  input  logic [7:0]  d_i,
  output logic [7:0]  q_o
);
  if (UseStage) begin : g_stage
    logic [7:0] q_q;
    if (ResetAll) begin : g_regs_ra
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)     q_q <= '0;
        else if (en_i)   q_q <= d_i;
      end
    end else begin : g_regs_nr
      always_ff @(posedge clk_i) begin
        if (en_i) q_q <= d_i;
      end
    end
    assign q_o = q_q;
  end else begin : g_no_stage
    assign q_o = d_i;
  end
endmodule
