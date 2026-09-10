# Pavona KMAC per-module equivalence

Keccak-MAC / SHA3 hashing core (OpenTitan `hw/ip/kmac`), vendored UNMODIFIED
from /home/alain/pavona. Per-module `read_uhdm` vs `read_slang` SAT miter,
mirroring the ACC/TL-UL campaigns.

- `rtl/kmac` — vendored KMAC RTL (16 files: sha3/keccak core + kmac control).
- Shares the prim library + base packages from `../pavona_tlul_equiv/rtl/{prim,
  tlul,pkg}` and `edn_pkg`/`keymgr_pkg` from `../pavona_acc_equiv/rtl/pkg`
  (no re-vendoring). `scripts/kmac_srcs.py` is the multi-root closure resolver
  (macro-instantiated modules like `prim_sparse_fsm_flop` are pulled in).
- `./run_kmac_equiv.sh [module]` — surelog → read_uhdm vs read_slang miter
  (`flatten; proc; opt; memory; async2sync`). `kmac_modules.txt` = the manifest.

## Status (kickoff)
- keccak_round: SAT-timeout (1600-bit Keccak-f permutation — cosim adjudication,
  like unified_mul).
- kmac_errchk / kmac_staterd / kmac_msgfifo: cex — frontend targets.
