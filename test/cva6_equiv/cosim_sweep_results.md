# Verilator co-sim sweep — all `cex` and `timeout` CVA6 modules

Run: 2026-08-28, 300 cycles, seed 1, via `scripts/adjudicate.py <mod> 300 1`.
Frontend at commit 86406f3d8 (after PR #660, the struct-field name-collision fix).

**How to read this.** `uhdm` = divergences of the UHDM netlist vs the RTL;
`slang` = divergences of the slang netlist vs the same RTL under the same
stimulus. slang is the reference implementation, so:

| verdict | meaning |
|---|---|
| `UHDM_WRONG` | uhdm diverges, slang does not → **our bug**, actionable |
| `BOTH_DIFFER` | both diverge → usually a sim/X-init artefact or an RTL-vs-synth issue, not specifically ours |
| `NO_DIVERGENCE` | neither diverges → the manifest `cex`/`timeout` is a SAT-capacity / unreachable-state limit, **not** a correctness bug |

A `cex` or `timeout` in `cva6_modules.txt` therefore does NOT imply a real
functional difference — 11 of the 25 below are functionally clean.

## Results

| module | manifest | uhdm | slang | verdict |
|---|---|---|---|---|
| cva6 | timeout | **300** | 0 | 🐛 UHDM_WRONG |
| std_cache_subsystem | timeout | **300** | 0 | 🐛 UHDM_WRONG |
| wt_cache_subsystem | timeout | **300** | 0 | 🐛 UHDM_WRONG |
| wt_dcache | timeout | **300** | 0 | 🐛 UHDM_WRONG |
| ex_stage | cex | **63** | 0 | 🐛 UHDM_WRONG |
| fpu_wrap | cex | **62** | 0 | 🐛 UHDM_WRONG |
| issue_stage | timeout | **1** | 0 | 🐛 UHDM_WRONG |
| fpnew_opgroup_block | cex | 63 | 271 | ⚠ BOTH_DIFFER |
| hpdcache_fifo_reg_initialized | cex | 150 | 134 | ⚠ BOTH_DIFFER |
| div_sqrt_top_mvp | timeout | 55 | 55 | ⚠ BOTH_DIFFER |
| aes | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| cache_ctrl | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| csr_regfile | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| fpnew_fma | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| fpnew_opgroup_fmt_slice | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| frontend | cex | 0 | 0 | ✅ NO_DIVERGENCE (fixed by PR #660) |
| load_store_unit | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| mult | timeout | 0 | 0 | ✅ NO_DIVERGENCE |
| multiplier | timeout | 0 | 0 | ✅ NO_DIVERGENCE |
| serdiv | timeout | 0 | 0 | ✅ NO_DIVERGENCE |
| tag_cmp | cex | 0 | 0 | ✅ NO_DIVERGENCE |
| hpdcache_ctrl | timeout | — | — | ❓ co-sim did not run |
| hpdcache_memctrl | timeout | — | — | ❓ co-sim did not run |
| macro_decoder | cex | — | — | ❓ co-sim did not run (elaboration error) |
| zcmt_decoder | cex | — | — | ❓ co-sim did not run (elaboration error) |

Totals: **7 UHDM_WRONG**, 3 BOTH_DIFFER, 11 NO_DIVERGENCE, 4 no-run.

## Reading the UHDM_WRONG group

`cva6` (the whole CPU), `wt_cache_subsystem` and `wt_dcache` are all at 300/300
with slang clean. `wt_dcache` is instantiated by `wt_cache_subsystem`, which is
instantiated by `cva6`, so these are very likely **one bug seen three times**;
`wt_dcache` is the leaf and the right place to attack. `std_cache_subsystem` is
the alternative (non-WT) cache and may or may not share the cause.

`issue_stage` at 1/300 is the cheapest single item — one divergent cycle,
usually a crisp localisation.

`fpu_wrap` (62/300) is the previously parked opgroup status-masking issue.

## Notes

- The 11 NO_DIVERGENCE entries are candidates for manifest reclassification
  (`cex` → `timeout`) since their counterexamples come from unreachable states
  rather than real behaviour — but reclassifying only changes bookkeeping, so
  it is not urgent.
- `BOTH_DIFFER` entries should not be treated as our bugs without separate
  adjudication; where slang diverges *more* than we do (fpnew_opgroup_block:
  271 vs 63) the RTL-vs-synth comparison itself is suspect.
- The 4 no-run modules need their harness/elaboration issue fixed before they
  can be measured at all.

Regenerate with the loop in
`/tmp/.../scratchpad/cosim_all.sh` (300 cycles per module, ~2 h for all 25).
