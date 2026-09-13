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
- kmac_core / sha3pad / sha3 / kmac_entropy: **proven** (seq=4) + cosim
  NO_DIVERGENCE.  (kmac_entropy needed `csrng_pkg`/`entropy_src_pkg`/
  `csrng_reg_pkg`, kmac_app `keymgr_reg_pkg` — vendored into
  ../pavona_acc_equiv/rtl/pkg next to edn_pkg/keymgr_pkg, else read_slang
  fails elaboration and the runner reports a bogus timeout/cex.)
- kmac_app / kmac_reg_top: **proven** + cosim NO_DIVERGENCE once the two
  Surelog fixes land (chipsalliance/Surelog PR: `inside {..}` parsed below
  `?:`; `$bits(arr[idx].member)` folded to the whole element struct).
  kmac_reg_top is mitered through `wrappers/flat_kmac_reg_top.sv` (2-element
  `tl_win_o/i` array ports → elem0@LSB flat buses, like tlul_socket_1n);
  `kmac_cosim.py` co-simulates the wrapper top when one exists.
  `scripts/cex_diff.py <sat -show-public log>` diffs a gold/gate counterexample
  per step (top-level, or `--all`).
- Remaining: kmac (top, EnMasking=1 → 2-share array ports), kmac_reduced.
- NOTE `kmac_cosim.py` regenerates `work/<mod>/cs_gold.v` / `cs_gate.v` when
  they are older than the plugin or the UHDM; delete them by hand to force it.
