# Pavona ACC per-module equivalence

`ACC` is Pavona's **Asymmetric Cryptography Coprocessor** — an OTBN-family
big-number / crypto core (ML-KEM / ML-DSA), the most active Pavona IP. This is
the per-module `read_uhdm` vs `read_slang` SAT-equivalence campaign for it, the
second Pavona-family target after TL-UL.

## Layout
- `rtl/acc/` — the vendored ACC RTL (`hw/ip/acc/rtl`, `bn_vec_core` flattened in).
- `rtl/pkg/` — the ACC-specific / IP packages it needs that the TL-UL campaign
  did not already vendor (`acc_pkg`, `acc_reg_pkg`, `otp_ctrl_pkg`, `keymgr_pkg`,
  `edn_pkg`, `kmac_pkg`, `lc_ctrl_state_pkg`, `lc_ctrl_reg_pkg`).
- The **shared prim library and base packages** are reused from the sibling
  `../pavona_tlul_equiv/rtl/{prim,tlul,pkg}` — no need to duplicate ~200 files.
- `scripts/acc_srcs.py <module>` — prints the per-module dependency **closure**
  (packages first, topologically) across all of the above roots.
- `run_acc_equiv.sh [module...]` — surelog → `read_uhdm` vs `read_slang` → SAT
  miter (`flatten; proc; opt; memory; async2sync; …` — the ACC modules contain
  memories, so `memory` mapping is required for SAT), checked against
  `acc_modules.txt` (a shrink-only ratchet).

## Status (kickoff)
7 leaf modules proven (`buffer_bit`, `acc_predecode`, `acc_decoder`,
`acc_digest_mux`, `acc_lsu`, `acc_alu_base`, `acc_rnd`).  Open next-round
targets: `acc_stack` / `acc_loop_controller` (real cex), `acc_start_stop_control`
(SAT timeout), and the bignum datapath (`unified_mul` and friends — SAT-hard
multipliers, to be adjudicated by cosim as `tlul_fifo_async` was).  The full ACC
top (`acc.sv`, `acc_reg_top`, scramble ctrl) is the eventual goal.

Refresh the RTL from an upstream checkout with the top-level `vendor_pavona.sh`
conventions.
