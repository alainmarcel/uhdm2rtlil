// Regression: a `unique case (1'b1) sig_a: … sig_b: …` one-hot case whose
// items are SIGNALS (not constants) writes `exc_pc`, and a later statement in
// the same always_comb reads it (`depc_d = exc_pc`).  thread_comb_case used to
// bail on the non-constant (wire) case-item compares — mistaking them for
// casez/casex wildcards — so the read saw the stale pre-case default instead of
// the case-selected value (ibex_cs_registers' exception_pc → depc_d, PR #<this>).
// Selects are onehot-decoded so the `unique case` has no illegal multi-hot input.
module onehot_case_nested (
  input  logic [1:0]  save_sel,
  input  logic        debug_save,
  input  logic [31:0] pc_if,
  input  logic [31:0] pc_id,
  input  logic [31:0] pc_wb,
  input  logic [31:0] wdata,
  output logic [31:0] depc_d
);
  logic save_cause, save_if, save_id, save_wb;
  logic [31:0] exc_pc;
  assign save_cause = 1'b1;
  always_comb begin
    save_if = (save_sel == 2'd0);
    save_id = (save_sel == 2'd1);
    save_wb = (save_sel == 2'd2);
    exc_pc = pc_id;                     // default
    depc_d = {wdata[31:1], 1'b0};        // default (other write path)
    unique case (1'b1)
      save_cause: begin
        unique case (1'b1)
          save_if: exc_pc = pc_if;
          save_id: exc_pc = pc_id;
          save_wb: exc_pc = pc_wb;
          default: ;
        endcase
        if (debug_save) depc_d = exc_pc; // read-after-case in same block
      end
      default: ;
    endcase
  end
endmodule
