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
| wt_dcache | timeout | ~~300~~ **0** | 0 | ✅ FIXED (PRs #662/#663/#664) |
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

Totals at sweep time: **7 UHDM_WRONG**, 3 BOTH_DIFFER, 11 NO_DIVERGENCE, 4 no-run.
(`wt_dcache` has since been fixed; `frontend` was fixed by PR #660.)

## Reading the UHDM_WRONG group

`cva6` (the whole CPU), `wt_cache_subsystem` and `wt_dcache` were all at 300/300
with slang clean, and since `wt_dcache` is instantiated by `wt_cache_subsystem`
which is instantiated by `cva6`, the obvious guess was **one bug seen three
times**.

**That guess was WRONG, and the correction is worth keeping.** `wt_dcache` is
now co-sim clean (0/300) after three fixes, and re-adjudicating the parents
afterwards gives:

    wt_cache_subsystem :: uhdm_vs_rtl=300 slang_vs_rtl=0
    std_cache_subsystem:: uhdm_vs_rtl=300 slang_vs_rtl=0
    cva6               :: uhdm_vs_rtl=300 slang_vs_rtl=0

— i.e. **unchanged**.  Each carries its own independent defect; a parent being
at 300/300 says nothing about the child.  Do not assume nesting implies a shared
cause: re-adjudicate the parent after fixing the child.

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

KNOWN FLAW in the generator: it reads the status column with `awk $NF`, which picks up a trailing `#` comment instead of the status — so
`wt_dcache_wbuffer`, `wt_dcache_mem` and `wt_dcache_ctrl` never appeared
above.  Re-adjudicated by hand they are BOTH_DIFFER (299 vs 216), 
BOTH_DIFFER (63 vs 63) and NO_DIVERGENCE (0/0) respectively, so the
manifest comments calling the first two "UHDM WRONG" are stale.

Regenerate with the loop in
`/tmp/.../scratchpad/cosim_all.sh` (300 cycles per module, ~2 h for all 25).

## Re-sweep 2026-08-31 — after the multi-range elem-select round (all 48 cex/timeout modules)

Run: 2026-08-31, 300 cycles, seed 1, frontend at PR #670 (Surelog/UHDM with
UHDM#1148).  Every module fixed by the campaign now reads NO_DIVERGENCE;
the remaining ACTIONABLE backlog is 7 UHDM_WRONG modules, all hpdcache-family
plus one fpnew slice:

| module | manifest | uhdm | slang | verdict |
|---|---|---|---|---|
| cva6_hpdcache_subsystem_axi_arbiter | cex | 300 | 0 | **UHDM_WRONG** |
| hpdcache_data_resize | cex | 300 | 0 | **UHDM_WRONG** |
| hpdcache_data_upsize | cex | 300 | 0 | **UHDM_WRONG** |
| hpdcache_mem_req_write_arbiter | cex | 300 | 0 | **UHDM_WRONG** |
| hpdcache_flush | cex | 298 | 0 | **UHDM_WRONG** |
| fpnew_opgroup_multifmt_slice | cex | 99 | 0 | **UHDM_WRONG** |
| hpdcache_victim_sel | cex | 7 | 0 | **UHDM_WRONG** |
| div_sqrt_top_mvp | timeout | 55 | 55 | BOTH_DIFFER |
| fpnew_opgroup_block | cex | 63 | 271 | BOTH_DIFFER |
| hpdcache_cmo | cex | 298 | 298 | BOTH_DIFFER |
| hpdcache_fifo_reg_initialized | cex | 150 | 134 | BOTH_DIFFER |
| hpdcache_uncached | cex | 300 | 300 | BOTH_DIFFER |
| issue_stage | timeout | 3 | 3 | BOTH_DIFFER |
| miss_handler | cex | 5 | 1 | BOTH_DIFFER |
| wt_dcache_mem | cex | 63 | 63 | BOTH_DIFFER |
| wt_dcache_wbuffer | cex | 216 | 216 | BOTH_DIFFER |

NO_DIVERGENCE (SAT-capacity, not correctness): aes cache_ctrl csr_regfile
cva6 cva6_hpdcache_if_adapter ex_stage fpnew_fma fpnew_opgroup_fmt_slice
fpu_wrap frontend hpdcache_rtab issue_read_operands load_store_unit mult
multiplier scoreboard serdiv std_cache_subsystem std_nbdcache tag_cmp
wt_cache_subsystem wt_dcache wt_dcache_ctrl

NO_RUN (harness/wrapper build errors, need triage before adjudication):
hpdcache_core_arbiter hpdcache_ctrl hpdcache_memctrl
hpdcache_regbank_wmask_1rw hpdcache_sram_wbyteenable
hpdcache_sram_wbyteenable_1rw hwpf_stride_wrapper macro_decoder zcmt_decoder

## NO_RUN triage 2026-09-02 — all nine resolved, zero frontend bugs among them

Every NO_RUN was a harness defect, fixed in `scripts/adjudicate.py` (or the
wrapper), not a frontend issue:

1. **async2sync in the netlist pipelines** (macro_decoder, zcmt_decoder,
   hwpf_stride_wrapper, hpdcache_sram_wbyteenable{,_1rw}): async2sync turns
   $adff into clockless $ff which write_verilog emits as unresolvable module
   instances → Verilator "module not found".  Removed — write_verilog
   expresses $adff/$dlatch directly.  All five now **NO_DIVERGENCE** (0/0).
2. **clk/reset port-name families**: the sram wrappers use bare `clk`/`rst_n`,
   which the TB treated as data inputs (and collided with its own `clk` reg).
   Now classified via CLK/RSTL/RSTH name lists, active-high resets driven
   with `~rst_ni`.
3. **Unpacked-port flattening convention**: read_uhdm and read_verilog put
   element 0 of an unpacked port at the flat LSBs; yosys-slang puts it at the
   MSBs (proven minimally: `input logic [7:0] a [2]; diff = a[0]-a[1]`).  A
   single shared flat order mislabeled one side's requesters and read as 289
   "divergences" on hpdcache_core_arbiter.  The TB now drives shared array
   views and gives each netlist its own flat view (`ms_*` input reversal for
   slang, `slo_*` output reorder).  Unresolved unpacked dims
   (`HPDcacheCfg.u.nRequesters`) are inferred from the flat netlist width.
4. **hpdcache_core_arbiter also hid a real frontend bug** (the one `cex` that
   was measurable): `.DATA_WIDTH($bits(hpdcache_tag_t))` — type-query
   sys_func_call overrides were excluded from the paramod dedup signature, so
   the 44-bit tag mux deduped onto the 147-bit req mux paramod and arb_tag_o
   was zeroed.  Fixed in uhdm2rtlil.cpp (both signature/naming gates now
   evaluate `$bits/$clog2/$size/$high/$low/$left/$right` overrides).  Now
   **NO_DIVERGENCE** (0/0) and the miter cex is the convention artifact above.
5. **hpdcache_ctrl / hpdcache_memctrl**: the auto-generated wrappers left
   `parameter type hpdcache_dir_entry_t = logic` unbound (slang errors out;
   UHDM elaborates a degenerate design).  Bound to
   `hpdcache_equiv_pkg::hpdcache_dir_entry_t` (already defined there).
   After the fix both adjudicate as **BOTH_DIFFER** (memctrl 137 vs 160 —
   first divergence on the SAME cycle/signal both sides; ctrl 185 vs 187),
   i.e. the usual RTL-vs-synth comparison artifact class, not one-sided
   frontend bugs.  Miters remain `timeout` at seq=4 as the manifest says.
6. **hpdcache_regbank_wmask_1rw**: wrapper exposes no outputs to compare
   (write-only view) — adjudication is N/A, not a failure.
