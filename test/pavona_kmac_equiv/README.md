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
- keccak_round: **proven** at seq=4 (it timed out until the compound-op RMW
  fix removed a combinational loop) and `scripts/kmac_cosim.py keccak_round
  2000`: **NO_DIVERGENCE** (was UHDM_WRONG: a 5-bug hydra — function returning a 3-D
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
- kmac_app / kmac_reg_top: **proven** + cosim NO_DIVERGENCE with Surelog
  #4170 (`inside {..}` was parsed below `?:`; `$bits(arr[idx].member)` was
  folded to the whole element struct).
  kmac_reg_top is mitered through `wrappers/flat_kmac_reg_top.sv` (2-element
  `tl_win_o/i` array ports → elem0@LSB flat buses, like tlul_socket_1n);
  `kmac_cosim.py` co-simulates the wrapper top when one exists.
  `scripts/cex_diff.py <sat -show-public log>` diffs a gold/gate counterexample
  per step (top-level, or `--all`).
- EnMasking=1 (Share=2) variants — sha3pad_m / keccak_2share_m / keccak_round_m
  (wrappers/flat_<mod>_m.sv instantiate the RTL module with `.EnMasking(1'b1)`
  and flatten the 2-element `[Share]` array ports elem0@LSB) and kmac_reduced:
  sha3pad_m / keccak_round_m (1500 s) / kmac_reduced / kmac **proven**,
  keccak_2share_m SAT-hard (timeout at 1500 s; co-sim clean with its output
  moving every cycle); all `check` 0 problems.  Fixes: always_ff `'{default:'0}` whole-array
  reset + per-element loop writes (temp mapping onto `$0\arr` slices, incl. the
  Share=1 same-width alias), gen-scope `sheet_t sheet0[Share]` element wires
  scope-qualified + packed-row `[k][W/2-1:0]` reads, case-arm whole-array
  writes `state_out = phase1_out` onto per-element temps (both halves landed on
  `$0\state_out[1]`), and `PiRotate[x][y]` / `RC[rnd]` table selects whose
  var_select Surelog leaves UNBOUND (Actual_group null) in the masked paramod —
  resolved by name on the instance (pi() had dropped every lane).
- kmac (full top, EnMasking=1): see the manifest line.
- **keccak_round's earlier "proven + NO_DIVERGENCE" was VACUOUS**: random
  `valid_i`/`run_i` violate `$onehot0` on cycle 1, the sparse FSM parks in its
  error state and `state_o` never moves; the seq=4 miter never completes a
  round either.  Evaluating the combinational keccak_2share stages against a
  Python Keccak reference found two datapath bugs that had slipped through:
  theta's `c[ThetaIndexX1[x]][z]` (a table-element bit_select in an index
  position was unwrapped to its own index `x`) and rho's
  `rho_in[x][y][ShiftAmt+:Offset]` (trailing indexed part-select on a packed
  3-D var_select returned 1 bit, 24/25 lanes dead).  `kmac_cosim.py` now prints
  `ACTIVITY (cycles each rtl output changed)` and applies `DIRECTED[mod]`
  stimulus (keccak_round / keccak_round_m: lc Off, clear MuBi4False, a valid
  pulse then a run pulse every 160 cycles, rand_valid held): both now show
  hundreds of state_o changes with 0 divergence.  Treat any module whose main
  outputs show ACTIVITY 0/1 as untested by the co-sim.
- Co-sim ACTIVITY sweep (1000 cycles, seed 1) after the fixes — all
  NO_DIVERGENCE, but the random stimulus only really drives: kmac_errchk
  (sw_cmd_o 953), kmac_staterd (tl_o 670), kmac_msgfifo (msg_data_o 540),
  kmac_core (msg_data_o 1000), kmac_entropy (rand_data_o 513), kmac_app
  (key_data_o 1000), kmac_reg_top (tl_o 1000), keccak_2share_m (s_o_flat
  1000), keccak_round / keccak_round_m (directed, state_o 249 / 688), kmac
  (tl_o 543, hashing idle).  **Vacuous** (main outputs never move — FSM parked
  by the random handshake): sha3pad, sha3pad_m, sha3, kmac_reduced.  Those
  rest on the seq=4 SAT miters only; a directed message-stream stimulus is
  the next step for them.
- NOTE `kmac_cosim.py` regenerates `work/<mod>/cs_gold.v` / `cs_gate.v` when
  they are older than the plugin or the UHDM; delete them by hand to force it.
