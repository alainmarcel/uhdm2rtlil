// Repro of CVA6 cva6_mmu.sv:522 `data_interface` spurious-latch class: an
// always_comb where some signals are assigned ONLY under a compile-time-FALSE
// parameter guard (`if (CVA6Cfg.RVH) begin lsu_tinst_n = …; end` with RVH==0).
// The body import folds the dead branch away, but the pre-pass still creates a
// `$0\sig` temp with a self-hold default (`$0\sig = \sig`) and an STa update
// (`\sig <= $0\sig`) for every syntactically-assigned signal — leaving the net
// effect `sig = sig`, which proc_dlatch turns into a latch.  read_verilog and
// slang leave the signal undriven instead (0 latches on the whole of CVA6).
//
// `dead_n` (internal) and `dead_o` (output port, like csr_hs_ld_st_inst_o)
// are only assigned under the dead guard and must NOT get temps/updates.
// `mix_n` has both a live and a dead assignment and must be kept.
// `fld_s` is assigned ONLY via struct-FIELD writes (hier_path LHS, like
// branch_unit's branch_exception_o) — all live — and must survive the prune
// (guards the collect/extract name-scheme mismatch).
module comb_dead_guard_latch #(
    parameter bit EN  = 1'b0,
    parameter bit SEL = 1'b1
) (
    input  logic [3:0] a_i,
    input  logic [3:0] b_i,
    input  logic       c_i,
    output logic [3:0] y_o,
    output logic [3:0] z_o,
    output logic       dead_o,
    output logic [4:0] f_o
);
  typedef struct packed {
    logic       v;
    logic [3:0] d;
  } fld_t;

  logic [3:0] dead_n;
  logic [3:0] mix_n;
  fld_t       fld_s;

  always_comb begin
    y_o   = a_i;
    mix_n = a_i & b_i;
    fld_s.v = c_i;
    fld_s.d = a_i ^ b_i;
    if (EN) begin
      dead_n = a_i ^ b_i;
      mix_n  = a_i | b_i;
      dead_o = c_i;
    end
    if (SEL) y_o = a_i + b_i;
    z_o = mix_n & dead_n;
    f_o = {fld_s.v, fld_s.d};
  end
endmodule
