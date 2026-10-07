// A $unit parameter whose value depends on another $unit parameter that is
// resolved LATER, where the dependency is NOT visible as a plain reference.
//
// import_unit_parameters resolves $unit parameters by fixed point, deferring
// any whose RHS still mentions an unresolved one.  `waits_for_pending` cannot
// see every such reference: scr1's
//   parameter bit [`SCR1_XLEN-1:ZERO_BITS] RST_VAL = WR_RST_VAL;
// arrives as an OPERATION whose operands do not expose the pending name, so
// RST_VAL -- alphabetically ahead of WR_RST_VAL -- folded on the FIRST pass
// against an unresolved reference and came back as a 1-BIT 1.  Widened to the
// declared 26 bits that is 1, not 7.
//
// scr1_pipe_csr reset its trap-vector base from it, so csr2exu_new_pc_o was
// 0x40 where 0x1c0 is correct and the module diverged from cycle 0 -- 231
// co-sim divergences with read_slang clean.  The guard is to DEFER a fold
// narrower than the declared width while other parameters are still pending.
`define XLEN 32
parameter int unsigned ZERO_BITS = 6;
parameter int unsigned VAL_BITS  = `XLEN - ZERO_BITS;
parameter bit [`XLEN-1:0] ARCH_BASE = 32'h1C0;
// decoys, so the resolution really does take several passes
parameter int unsigned D_A = ZERO_BITS + 1, D_B = D_A + 1, D_C = D_B + 1;
parameter bit [`XLEN-1:ZERO_BITS] M_WR_RST_VAL = VAL_BITS'(ARCH_BASE >> ZERO_BITS);
parameter bit [`XLEN-1:ZERO_BITS] A_RST_VAL    = M_WR_RST_VAL;

module dut (
    output logic [25:0] rst_val,
    output logic [25:0] wr_rst_val,
    output logic [31:0] new_pc
);
  assign rst_val    = A_RST_VAL;                 // 7
  assign wr_rst_val = M_WR_RST_VAL;              // 7
  assign new_pc     = {A_RST_VAL, {ZERO_BITS{1'b0}}};   // 0x1c0
endmodule
