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

## Status
- keccak_round: formal SAT-timeout (1600-bit Keccak-f permutation, like
  unified_mul) — adjudicated by `scripts/kmac_cosim.py keccak_round 2000`:
  **NO_DIVERGENCE** (was UHDM_WRONG: a 5-bug hydra — function returning a 3-D
  packed array via var_select writes, bit_select element width on typedef'd
  packed locals, trailing part-select on a packed var_select, N-D unpacked
  param-array element as an index, and an always_comb whole-array default on a
  mixed unpacked array followed by element chunk writes that double-drove the
  element aliases — `storage_d = keccak_out; … storage_d[j][i*DIN+:DIN] = …`).
- kmac_errchk / kmac_staterd / kmac_msgfifo: proven / cosim NO_DIVERGENCE.
- NOTE `kmac_cosim.py` regenerates `work/<mod>/cs_gold.v` / `cs_gate.v` when
  they are older than the plugin or the UHDM; delete them by hand to force it.
