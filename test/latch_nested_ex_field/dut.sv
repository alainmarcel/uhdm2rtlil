// Repro of CVA6 decoder.sv:1840 exception_handling latches + dropped default:
// THREE always_comb blocks write different slices of one output struct, so the
// third block's temp wire is dedup-bumped to `$2\instr_o`.  Its root-level
// whole-member copy (`instr_o.ex = ex_i_s`) was remapped by the NAME-based
// `module->wire("$0\\" + sig)` fallback onto the FIRST process's `$0\instr_o`
// temp — an orphan in this process (its sync rule updates from `$2`) — so the
// unconditional default was DROPPED: `instr_o.ex` held stale data (latches on
// the ex slices, overrides routed through a phantom latch).  slang: 0 latches.
module latch_nested_ex_field (
    input  logic [7:0]  instr_i,
    input  logic        illegal_i,
    input  logic        tval_en_i,
    input  logic        ex_valid_i,
    input  logic [4:0]  ex_cause_i,
    input  logic [7:0]  ex_tval_i,
    output logic [21:0] instr_flat_o
);
  typedef struct packed {
    logic [4:0] cause;
    logic [7:0] tval;
    logic       valid;
  } ex_t;
  typedef struct packed {
    logic [3:0] pc;
    logic [1:0] fu;
    ex_t        ex;
    logic       valid;
    logic       bp;
  } entry_t;

  ex_t    ex_i_s;
  entry_t instr_o;

  assign ex_i_s.cause = ex_cause_i;
  assign ex_i_s.tval  = ex_tval_i;
  assign ex_i_s.valid = ex_valid_i;

  // Process 1: writes TWO slices -> collapses to full-width `$0\instr_o`
  always_comb begin
    instr_o.pc = instr_i[3:0];
    instr_o.fu = instr_i[5:4];
  end

  // Process 2: writes TWO slices -> collapses to full-width `$1\instr_o`
  always_comb begin
    instr_o.valid = ex_valid_i | illegal_i;
    instr_o.bp    = tval_en_i & illegal_i;
  end

  // Process 3: temp bumped to `$2\instr_o`; the root default below must land
  // on THIS process's temp, not process 1's `$0\instr_o`.
  always_comb begin : exception_handling
    instr_o.ex = ex_i_s;
    if (~ex_i_s.valid) begin
      if (tval_en_i) instr_o.ex.tval = instr_i;
      else instr_o.ex.tval = '0;
      if (illegal_i) begin
        instr_o.ex.valid = 1'b1;
        instr_o.ex.cause = 5'd2;
      end
    end
  end

  assign instr_flat_o = instr_o;
endmodule
