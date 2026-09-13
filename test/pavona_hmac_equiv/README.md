# Pavona HMAC per-module equivalence

HMAC-SHA2 core (OpenTitan `hw/ip/hmac`), vendored UNMODIFIED from
/home/alain/pavona. Per-module `read_uhdm` vs `read_slang` SAT miter, mirroring
the KMAC / ACC / TL-UL campaigns.

- `rtl/hmac` — vendored HMAC RTL (hmac, hmac_core, hmac_reg_top, hmac_reg_pkg).
- Shares the prim library (prim_sha2_*, prim_packer, prim_fifo_sync, prim_intr_hw,
  prim_subreg*, prim_alert_sender) + tlul + base packages from
  `../pavona_tlul_equiv/rtl/{prim,tlul,pkg}` and edn/keymgr packages from
  `../pavona_acc_equiv/rtl/pkg` — nothing re-vendored.
- `./run_hmac_equiv.sh [module]` — surelog → read_uhdm vs read_slang miter
  (`flatten; proc; opt; memory; async2sync`). `hmac_modules.txt` = manifest.
- `scripts/hmac_cosim.py <mod> [cycles] [seed]` — Verilator co-sim of RTL vs
  the read_uhdm and read_slang netlists under random stimulus; prints the
  per-output ACTIVITY line (a compare whose outputs never move proves nothing)
  and takes `DIRECTED[mod]` overrides.

## Status
- **All 10 manifest modules proven** (seq=4): prim_sha2_pad, prim_sha2_compression,
  prim_sha2, prim_sha2_32, prim_sha2_mm / prim_sha2_32_mm (MultimodeEn=1, the
  configuration hmac instantiates — via `wrappers/flat_prim_sha2*_mm.sv`),
  prim_packer (SAT-hard, ~20 min), hmac_core, hmac_reg_top, hmac.
- Co-sim (`hmac_cosim.py <mod> 1000 1`): NO_DIVERGENCE on every module with
  real output activity (hmac_core hash_done_o 574 / sha_rdata_o 1496 changes
  in 1500 cycles; hmac tl_o 833; prim_packer data_o 513).  hmac_core needed
  UHDM PR #1153 (Surelog #4171, bumped here): `localparam bit [63:0] BlockSizeSHA256in64
  = 64'(BlockSizeSHA256)` folded to 0 in UHDM's ExprEval (`1ULL << 64` is
  undefined), so the OPad message lengths were 256/384/512 instead of
  768/1408/1536.  The seq=4 miter could not see it (the reader re-evaluates
  the localparam itself; only the constants Surelog derived from it were
  wrong, deep in the outer round) — the random co-sim caught it at cycle 363.
  With the fix the co-sim is clean.
