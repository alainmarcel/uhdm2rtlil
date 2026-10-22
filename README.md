# UHDM to RTLIL Frontend

**Gates** (every PR + nightly) — a PR lands only on a clean run:

[![CI](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml) [![Regression (sharded)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml) [![Frontend matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml)

**Nightly IP sweeps** — one badge per sweep workflow, in the order the [Supported Core IP](#supported-core-ip) table lists them; each links to its per-module report:

[![ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) [![rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) [![fx68k](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml) [![scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml) [![rggen](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml) [![veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml) [![tnoc](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml) [![veer-el2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml) [![rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml) [![black-parrot](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml) [![opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) [![pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) [![cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) [![cva6 flavours](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml) [![caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) [![xiangshan core](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml) [![external IP](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) [![sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language). Focused on creating post-synthesis (Gate-level) netlists that matches RTL simulation using Verilator as the golden standard.

> ### ✅ Every result is verified
> Nothing here is counted as "working" on a read-only or vacuous pass. Every
> synthesized netlist is proven correct by **formal equivalence** — Yosys
> `equiv_induct` plus a sound **SAT-from-reset miter** against the Yosys
> Verilog-frontend golden — **and/or** by **high-activity randomized Verilator
> co-simulation** against the original RTL. A SAT miter also adjudicates every
> divergence so an inductive-proof gap is never mistaken for a real bug.
> See **[Verification Methodology](#verification-methodology)** below.

## Overview

This project bridges the gap between SystemVerilog source code and Yosys synthesis by leveraging two key components:

1. **Surelog** - Parses SystemVerilog and generates UHDM
2. **UHDM Frontend** - Converts UHDM to Yosys RTLIL

This enables full SystemVerilog synthesis capability in Yosys, including advanced features not available in Yosys's built-in Verilog frontend.

## Verification Methodology

Correctness is the project's first-class concern. Every test's SystemVerilog is
synthesized and then **independently verified** by one or more of:

1. **Formal equivalence (`equiv_induct`)** — the UHDM-frontend netlist is proven
   sequentially equivalent to the netlist produced by Yosys's own Verilog frontend
   (the golden reference), using `equiv_make` / `equiv_simple` / `equiv_induct`.
2. **Sound SAT-from-reset miter** — a bounded model-check from the reset state
   (`miter` + `sat -prove-asserts -seq N -set-init-zero`) that is **sound**: it
   never false-passes. It is the adjudicator of record — when `equiv_induct` can't
   close an inductive proof, the miter decides whether the two netlists are truly
   equivalent (an induction gap, *not* a bug) or genuinely divergent (a real bug).
3. **High-activity randomized Verilator co-simulation** — the UHDM-synthesized
   gate-level netlist is co-simulated against the original RTL under randomized,
   high-toggle-activity stimulus (all clocks driven, reset wiggled, activity
   guards) to catch functional divergences a vacuous stimulus would miss.

A result is only counted as **Correct** when formal equivalence and/or co-simulation
proves it; designs the native Verilog frontend cannot even parse ("SV-only") are
verified against the RTL by co-simulation, since there is no golden netlist to
compare against. This asymmetric, miter-adjudicated policy is why the tables below
report **0 Miter-Formal escapes** — no real UHDM≠Verilog difference slips through.

### Test Suite Status

`make test-all --all` runs the internal SystemVerilog suite plus the upstream
Yosys suite, and is the same run as the sharded
[Regression](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml)
workflow (every PR + nightly).  Local developer run:
`cd test && ./run_parallel.sh 6 --no-cva6` (the 1314 internal tests, ~24 min).  A PR
lands only on a clean run.  The counts below are the regression's own summary
(`Total tests run` / per-suite lines of the combined report), not a tally kept
by hand; "upstream" counts the 514 generated yosys tests the suite scored in
that run (the deliberately invalid `tests/errors` and tests that produce no RTLIL
under any frontend are generated but not scored).  Counts are the regression of
main at `f65702a6c` (2026-10-22, run 39719454412 -- the tree the 2026-10-22
nightly sweeps below ran on), split internal / upstream by the `run/` prefix of
the shard result lists.
The 11 upstream failures are the **Yosys 0.70** bump's, unchanged since #1186
and each recorded in `failing_tests.txt`; crashes have been **0** since it.

| | Total | Internal SV | Upstream Yosys |
|---|---|---|---|
| Tests | 1856 | 1342 | 514 |
| Functional | 1808 (97%) | 1305 | 503 |
| True failures | 11 | **0** | 11 |
| Crashes | **0** | **0** | **0** |

- **0 Miter-Formal escapes** — no UHDM≠Verilog difference slips past
  `equiv_induct`.  This is the number that matters: every equivalence failure
  is one `equiv_induct` caught.
- **1092** tests formally equivalent UHDM vs Verilog; **716** UHDM-only
  (constructs `read_verilog` cannot parse) verified against Verilator;
  **332 / 333** SV-only designs also proven against `read_slang` (1 known-fail,
  tracked in `test/slang_miter_expected_fail.txt`), and **73**
  carry a `test_structural.ys` netlist-SHAPE gate for defects no formal check
  can see (a dropped flop, a missing `$mem` or a dropped clock connection still
  "works" — it just returns constants).
- **16 equivalence failures**, each with a recorded verdict in
  `test/failing_tests.txt`.  In several the *reference* is the wrong side
  (`read_verilog` mis-lowers the construct) — a SAT miter against `read_slang`
  proves UHDM correct.
- **Sim-equiv ratchet** (`test/sim_equiv_warn_baseline.txt`, shrink-only): 84
  divergences outstanding across the full corpus; 75 analyzed, 58 shown to be
  sim/synth artefacts a miter proves UHDM == Verilog, 17 still inconclusive
  (adjudication-miter budget under the 12-shard CI load, not counterexamples).
  Restricted to the internal SV suite the backlog is 22, and all 55 analyzed
  ones are artefacts with 0 inconclusive (local `run_parallel.sh` of the same
  commit).


### Supported Core IP

Real-world (System)Verilog IP swept end-to-end through the UHDM frontend.
Every family is **upstream RTL, imported verbatim** (no source edits) from the
repo and commit named below, and each has a nightly sweep publishing a
per-module table to its run summary.

Every row runs the same four checks: the `read_slang` netlist's own Verilator
co-sim against the RTL (the **baseline** — it says whether the RTL is even
co-simulable), formal equivalence read_uhdm vs `read_slang` (SAT miter from
reset), a structural opt-check for dropped drivers (undriven nets), and the
read_uhdm Verilator co-sim.  A SAT miter adjudicates every divergence, so a
proof gap is never mistaken for a bug.

| IP | Source | Scope | Result | Sweep |
|----|--------|-------|--------|-------|
| **Ibex** | [lowRISC/ibex](https://github.com/lowRISC/ibex) | 2-stage RV32IMC core (+PMP, ICache, lockstep); 28 modules incl. `ibex_top` | **22 / 28 proven** · 20 / 24 co-sim, 0 `read_uhdm` divergences (4 adjudicated artefacts) · 28 / 28 opt-clean · 1 `differs` formal-only, 1 over the SAT budget, 4 no `read_slang` reference · `read_slang` itself diverges on 3 | [ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) |
| **rp32 (R5P)** | [jeras/rp32](https://github.com/jeras/rp32) | 32-bit cores + TCB SoCs; 13 modules | **6 / 13 proven** · 3 / 7 co-sim, 0 divergences (4 adjudicated artefacts) · 13 / 13 opt-clean · 7 rows have no `read_slang` reference · both SoCs boot and run a program · `read_slang` diverges on 3 | [rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) |
| **fx68k** | [ijor/fx68k](https://github.com/ijor/fx68k) @ [`0602ee46`](https://github.com/ijor/fx68k/commit/0602ee4627b10f301298f2673d826cdd6baa9327) (the commit chipsalliance/sv-tests pins) | Cycle-accurate **Motorola 68000** — the one non-RISC-V CPU core in the sv-tests list: sequencer, microcode/nanocode ROMs and their address PLA, ALU and shifter, bus arbiter/controller, exception unit; 22 modules from three files | **18 / 22 proven** · 6 / 10 co-sim, 0 divergences (4 adjudicated artefacts) · 21 / 21 opt-clean · 1 `differs` formal-only, 3 no `read_slang` reference · `read_slang` diverges on 6 of the 12 it co-simulates | [fx68k](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml) |
| **Syntacore SCR1** | [syntacore/scr1](https://github.com/syntacore/scr1) @ [`ebb5e355`](https://github.com/syntacore/scr1/commit/ebb5e3551a9d93c0ee95f0b767dd878b8927e702) | RV32IMC core, pipeline and the AXI/AHB SoC tops; 37 modules | **29 / 37 proven** · 32 / 32 co-sim, 0 divergences · 37 / 37 opt-clean · 2 `differs` formal-only (`scr1_dm`'s Surelog enum-value fold is fixed, #4208 / #1091) · 6 over the SAT budget | [scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml) |
| **RgGen** | [rggen/rggen-sv-rtl](https://github.com/rggen/rggen-sv-rtl) @ [`6b3f25a0`](https://github.com/rggen/rggen-sv-rtl/commit/6b3f25a08fdbe87c6ab0bccbf83d9a16eb6974f7) + [rggen/rggen-sample](https://github.com/rggen/rggen-sample) @ [`9458b9ff`](https://github.com/rggen/rggen-sample/commit/9458b9ffd6d9bb5b4b23a0d66b55ae6c653e8012) (the commits chipsalliance/sv-tests pins) | Register-file generator: the hand-written library (bit fields and their counters/triggers, register and adapter commons, APB / AXI4-Lite / Avalon / Wishbone / native bridges, the address decoder, the mux and its recursive OR reducer) plus the generated sample blocks; 26 modules over two repos | **25 / 25 proven — the family is clean** · 25 / 25 co-sim, 0 divergences · 25 / 25 opt-clean · 0 `differs`, 0 over budget, 0 rows without a reference (the four `differs` rows of 2026-10-16 are all fixed) | [rggen](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml) |
| **VeeR EH1** | [chipsalliance/Cores-VeeR-EH1](https://github.com/chipsalliance/Cores-VeeR-EH1) @ [`d04b1c7a`](https://github.com/chipsalliance/Cores-VeeR-EH1/commit/d04b1c7ae675a63dc4307cacfd10547ec937b928) | RV32IMC core (`veer` / `veer_wrapper`), its IFU/DEC/EXU/LSU/DBG blocks, the `rv*` primitive library and the AHB/AXI4 bridges; 66 modules | **55 / 67 proven** · 66 / 66 co-sim, 0 divergences · 67 / 67 opt-clean · whole core `veer` equivalent + co-sim PASS · 0 undriven, 0 read errors · 11 over the SAT budget, 1 no reference | [veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml) |
| **TNoC** | [taichi-ishitani/tnoc](https://github.com/taichi-ishitani/tnoc) @ [`7e9841ff`](https://github.com/taichi-ishitani/tnoc/commit/7e9841ff775ea22fba3f222f7bdfe35668345e00) (the commit chipsalliance/sv-tests pins) | Network-on-chip: the fabric and its routers, input/output blocks and switches, the virtual-channel arbiter / merger / mux / splitter, the packet serializer and deserializer, the AXI master and slave adapters, over the `tbcm_*` basic-component library (a submodule); 43 modules | **16 / 43 proven** · 12 / 12 co-sim, **0 divergences** · 24 / 24 opt-clean · 2 `differs` formal-only (`tnoc_dummy_node` and `tnoc_flit_if_dummy_sender`, degenerate dummies whose co-sim is `0 active` and passes) · 25 rows have no `read_slang` reference (its interface-array ports) · `tnoc_packet_serializer`, `tnoc_packet_deserializer` and `tnoc_error_checker` were fixed by a Surelog const-function fold (chipsalliance/UHDM#1166, chipsalliance/Surelog#4221) | [tnoc](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml) |
| **VeeR EL2** | [chipsalliance/Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) @ [`c2ea3a73`](https://github.com/chipsalliance/Cores-VeeR-EL2/commit/c2ea3a7382dd73ff8ff8c38f257382dfdd91be5e) (the commit chipsalliance/sv-tests pins) | RV32IMC core (`el2_veer_wrapper` / `el2_veer`), its IFU/DEC/EXU/LSU/DBG/PIC/PMP/DMA blocks, the lockstep shadow and the rv* primitive library; 91 modules (`rvclkhdr` excluded) | **77 / 91 proven** · 87 / 87 co-sim, **0 divergences** · 91 / 91 opt-clean, 0 undriven · the six ICCM/DCCM/I-cache memory wrappers (`EL2_IC_DATA`, `EL2_IC_TAG`, `el2_ifu_ic_mem`, `el2_ifu_iccm_mem`, `el2_lsu_dccm_mem`, `el2_mem`) diverged by 171-300 cycles until #1258 fixed the interface-member select they all share · 1 `differs`, 8 over budget, 5 no reference · `rvclkhdr` is excluded: it sits inside `ifndef RV_FPGA_OPTIMIZE` and is not compiled in the swept configuration (#1260) | [veer-el2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml) |
| **RSD** | [rsd-devel/rsd](https://github.com/rsd-devel/rsd) @ [`7b65f6ba`](https://github.com/rsd-devel/rsd/commit/7b65f6ba) | Out-of-order superscalar RISC-V core (RV32IMF) — the `Core` sv-tests builds, its front end, rename / issue / commit stages, FP pipelines and cache hierarchy; 165 rows after its interfaces and test benches are set aside | **116 / 165 proven** · 146 / 147 co-sim, **0 divergences** (1 adjudicated artefact) · 151 / 151 opt-clean · `PerformanceCounter` regressed for one day on 2026-10-19 and was fixed the same day in #1257 · 7 `differs` formal-only, 23 over the SAT budget, 19 no `read_slang` reference · `read_slang` diverges on 4 | [rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml) |
| **BlackParrot** | [black-parrot/black-parrot](https://github.com/black-parrot/black-parrot) @ [`710b0ea9`](https://github.com/black-parrot/black-parrot/commit/710b0ea998c3b2f70ef9671d5619e439f13f826c) (the commit chipsalliance/sv-tests pins) | Linux-capable RV64 multicore (`wrapper` / `bp_processor`): the FE/BE/ME complexes, the CCE/LCE coherence engines, the bedrock network, over `basejump_stl` + `HardFloat` (three repos); 125 modules | **50 / 125 proven** · 44 / 45 co-sim, 0 `read_uhdm` divergences (1 adjudicated artefact) · 83 / 83 opt-clean · 2 `differs` formal-only, 8 over the SAT budget · 65 rows have no `read_slang` reference (28 of them read_slang cannot elaborate) · `read_slang` diverges on 3 | [black-parrot](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml) |
| **OpenTitan** (upstream) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) @ [`f49474bc`](https://github.com/lowRISC/opentitan/commit/f49474bc89c3ce8a99536329a1e16bf22936da37) | [OTBN](https://github.com/lowRISC/opentitan/tree/master/hw/ip/otbn/rtl) 256-bit bignum accelerator; 32 modules, 122 files | **28 / 32 proven** · 28 / 29 co-sim, 0 divergences (1 adjudicated artefact) · 32 / 32 opt-clean · 4 SAT timeouts (256-bit datapaths) · `read_slang` diverges on 2 · `otbn_rf_bignum_fpga` went from a read-fail to a full pass in #1254 (a generate-scope block-local memory was one memory shared by every instance) | [opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) |
| **OpenTitan IP library** (upstream) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) @ [`f49474bc`](https://github.com/lowRISC/opentitan/commit/f49474bc89c3ce8a99536329a1e16bf22936da37) | The other 44 of OpenTitan's 45 IP blocks -- `hw/ip`, `hw/ip_templates` and top_earlgrey's generated IP, over the vendored RISC-V debug module and `prim_generic`; 605 modules, 817 RTL files.  Pavona is a hard fork of this tree and is swept separately | **first nightly pending** -- measured locally before landing (#1268): a 1/12 shard **41 / 47 comparable proven**, and the large blocks sampled separately all proven with clean 301-cycle co-sims (`otp_ctrl`, `spi_device`, `usbdev`, `aes_cipher_core`, `sha3`, `keymgr_dpe`, `dma`, `mbx`, `ascon_core`, `hmac_core`, `kmac_core`, `lc_ctrl`, `rv_dm`) · three candidate reader defects already on the first shard, all `read_slang` clean: `prim_gf_mult` (300 diverging cycles), `rram_phy_rd_buf_dep` (73), `i3c_target_fsm` (`differs`) | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **Pavona** | [pavona/pavona](https://github.com/pavona/pavona) @ [`61ebeba1`](https://github.com/pavona/pavona/commit/61ebeba10cafca3b0dd43786fa79d26882a5ccf5) | OpenTitan-derived SoC family: hardened Ibex, TL-UL fabric, 27 crypto/peripheral IPs, 2 full chips; 300 module rows + 98 chip instances | **381 / 400 proven** · 380 / 389 co-sim, 0 `read_uhdm` divergences (9 adjudicated artefacts; both full chips build and co-simulate) · 395 / 395 opt-clean · 14 over the SAT budget, 3 miter errors · `read_slang` diverges on 11 | [pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) · [per-IP table](docs/pavona_sweep.md) |
| **Ariane CVA6** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | 6-stage 64-bit app-class core (`cv64a6_imafdc_sv39`) + HPDcache, FPnew; 142 modules, plus the full core split into its 138 distinct instantiations (366 instances paired with `read_slang`) | **228 / 280 proven** (142 modules 99, 138 core instantiations 129) · 126 / 135 co-sim, 0 `read_uhdm` divergences (9 adjudicated artefacts) · 273 / 273 opt-clean, 0 undriven on every row · full core lowers with 0 inferred latches · 6 `differs`, all adjudicated non-defects (see below), 39 over the SAT budget, 3 miter errors | [cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) |
| **Ariane CVA6 flavours** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | The three OTHER configurations chipsalliance/sv-tests builds the core at: `cv64a6_imafdc_sv39_hpdcache` (the HPDcache subsystem instead of the write-through cache), `cv64a6_imafdch_sv39` (the hypervisor extension) and `cv32a6_imac_sv32` (32-bit, Sv32, no FPU).  The same RTL at a different `*_config_pkg.sv`, swept per module like the default; 429 rows over three families | **301 / 429 proven** (hpdcache 99 / 145, H-extension 100 / 142, RV32 102 / 142) · 372 / 402 co-sim · **2 `read_uhdm` divergences** (`cva6_hpdcache_subsystem` 2 cycles, `cva6_hpdcache_wrapper` 3, both at the HPDcache flavour and `read_slang` clean -- the next targets) · 28 adjudicated artefacts · 408 / 408 opt-clean · 15 `differs`, every one the same five adjudicated non-defects the default configuration carries (`csr_regfile`, `zcmt_decoder`, `macro_decoder`, `hpdcache_cmo`, `hpdcache_uncached`) seen three times · 92 over the SAT budget · the HPDcache flavour measures `hpdcache`, `cva6_hpdcache_subsystem` and `cva6_hpdcache_wrapper` for the first time: all three are `dead` at the default configuration | [cva6-flavours](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml) |
| **Caliptra** | [chipsalliance/caliptra-rtl](https://github.com/chipsalliance/caliptra-rtl) | Root-of-trust SoC: VeeR EL2, AXI, mailbox, SHA/HMAC/ECC/Ascon, ML-DSA/ML-KEM; 867 modules, 172 instances | **20 / 22 instances proven** · 21 / 21 co-sim, 0 divergences · 21 / 21 opt-clean, 0 driver conflicts · full-chip co-sim NO_DIVERGENCE over 401 cycles | [caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) |
| **XiangShan** (香山) | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) @ [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | the project's **hand-written** SystemVerilog arithmetic library — SRT dividers, radix-2/4/16 FP divide-sqrt, LZC, CSA, QDS; 21 modules.  **Not the core**, which is Chisel | **19 / 21 proven** · 21 / 21 co-sim, 0 divergences · 21 / 21 opt-clean · 2 SAT timeouts (64-bit divide datapaths) | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **XiangShan core** (香山) | [OpenXiangShan/XiangShan](https://github.com/OpenXiangShan/XiangShan) @ [`e4566c29`](https://github.com/OpenXiangShan/XiangShan/commit/e4566c29e251c60159c6796db60a2569dd7700f2) | Kunminghu out-of-order RV64 core, `CONFIG=DefaultConfig`.  **There is no Verilog to read**: the RTL is the Chisel generator's output (1980 `.sv` + 22 `.v`, 3.2 M lines, 2002 modules, one per file), published as the release asset [`xiangshan-rtl-e4566c29`](https://github.com/alainmarcel/uhdm2rtlil/releases/tag/xiangshan-rtl-e4566c29) and swept module by module in 16 CI shards | whole core elaborates clean (1981 modules / 6.52 M cells, 1 warning) · per-module **1602 / 2002 proven** · 1944 / 1944 co-sim, 0 divergences · 1994 / 1994 opt-clean · 392 over the SAT budget · `read_slang` diverges on 3 | [xiangshan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml) |
| **External IP** (11 repos) | see table below | Breadth sweep over third-party (System)Verilog *not* covered above — no vendored copy, each repo fetched at a pinned commit (`test/ext_ip/<family>.json`) | **865 / 949 comparable proven** of 1023 rows (the XiangShan library's 21 rows have their own line) · 889 / 913 co-sim, **0 `read_uhdm` divergences** (24 adjudicated artefacts) · 985 / 985 opt-clean · 74 rows not comparable · the five caliptra-ss rows that vendor VeeR EL2's memory wrappers as `css_mcu0_*` were fixed with the EL2 ones in #1258 | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **chipsalliance/sv-tests** | [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests) @ [`db159ad8`](https://github.com/chipsalliance/sv-tests/commit/db159ad8e9cbbd62036569d240153f753258f640) | The LRM-chapter conformance corpus, not a design: 708 synthesizable tests of its own local suite (`tests/chapter-*`, `generic`, `sanity.sv`). The cores it also defines are swept per core | **read_uhdm 689 / 708** vs read_verilog 364, read_slang 682 · 474 / 527 proven · 527 / 527 opt-clean, 0 conflicts · co-sim on 12 rows, **0 divergences**: the one row that diverged is `force` / `release`, which has no synthesis semantics on either side, and it is now adjudicated in `test/sv_tests_cosim_analyzed.txt` (#1261) | [sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml) · [per-test table](docs/sv_tests_coverage.md) |

#### Co-simulation per core: `read_slang` vs `read_uhdm`

Every sweep row co-simulates **both** netlists against the same RTL under the
same random stimulus, so the reference frontend is measured by the same yardstick
as this one.  The columns are disjoint counts and the arithmetic holds on every
line and in the total:

- *co-simulated* = rows whose netlist got a Verilator run at all;
  **Rows − co-simulated** = rows with no co-sim for that netlist (no ports — 514
  of the 526 sv-tests snippets — no buildable testbench, no default
  elaboration, or a formal-only instantiation row).
- `read_slang`: **co-simulated = pass + diverge**.
- `read_uhdm`: **co-simulated = pass + diverge + artefact**, where *artefact* is
  a divergence a SAT miter proved to be a simulation artefact (X-semantics,
  unique/priority-case violation stimulus), not a reader defect, and
  **diverge** is a real one.
- The rows are the rows of the Supported Core IP table above, in its order
  (the sweep links are there); the XiangShan library has its own row, so the
  External IP row is the other 10 repos and every column sums to its total.
  The script asserts both identities before printing.

| Core | Rows | Formal proven | `read_slang` co-simulated | pass | **diverge** | `read_uhdm` co-simulated | pass | **diverge** | artefact | Undriven |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **Ibex** | 28 | 22 | 23 | 20 | **3** | 24 | 20 | 0 | 4 | 0 |
| **rp32 (R5P)** | 13 | 6 | 5 | 2 | **3** | 7 | 3 | 0 | 4 | 0 |
| **fx68k** | 22 | 18 | 12 | 6 | **6** | 10 | 6 | 0 | 4 | 0 |
| **Syntacore SCR1** | 37 | 29 | 32 | 32 | 0 | 32 | 32 | 0 | 0 | 0 |
| **RgGen** | 25 | 25 | 25 | 25 | 0 | 25 | 25 | 0 | 0 | 0 |
| **VeeR EH1** | 67 | 55 | 66 | 66 | 0 | 66 | 66 | 0 | 0 | 0 |
| **TNoC** | 43 | 16 | 12 | 12 | 0 | 12 | 12 | 0 | 0 | 0 |
| **VeeR EL2** | 91 | 77 | 86 | 86 | 0 | 87 | 87 | 0 | 0 | 0 |
| **RSD** | 165 | 116 | 144 | 140 | **4** | 147 | 146 | 0 | 1 | 0 |
| **BlackParrot** | 125 | 50 | 45 | 42 | **3** | 45 | 44 | 0 | 1 | 0 |
| **OpenTitan** (upstream) | 32 | 28 | 29 | 27 | **2** | 29 | 28 | 0 | 1 | 0 |
| **Pavona** (300 modules + 100 chip instances) | 400 | 381 | 389 | 378 | **11** | 389 | 380 | 0 | 9 | 0 |
| **Ariane CVA6** (142 modules + 138 core instantiations, the latter formal-only) | 280 | 228 | 135 | 124 | **11** | 135 | 126 | 0 | 9 | 0 |
| **Ariane CVA6 flavours** (the three other sv-tests configurations: HPDcache, H-extension, RV32) | 429 | 301 | 402 | 365 | **37** | 402 | 372 | **2** | 28 | 0 |
| **Caliptra** | 22 | 20 | 21 | 21 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan** (香山) | 21 | 19 | 21 | 21 | 0 | 21 | 21 | 0 | 0 | 0 |
| **XiangShan core** (香山) | 2002 | 1602 | 1944 | 1941 | **3** | 1944 | 1944 | 0 | 0 | 0 |
| **External IP** (the other 10 repos; the XiangShan library is the row above) | 1023 | 865 | 893 | 863 | **30** | 913 | 889 | 0 | 24 | 0 |
| **chipsalliance/sv-tests** | 527 | 474 | 11 | 11 | 0 | 12 | 11 | 0 | 1 | 0 |
| **All sweeps** (18 workflows) | **5352** | **4332** | **4295** | **4182** | **113** | **4321** | **4233** | **2** | **86** | **0** |

**Two `read_uhdm` divergences remain, and both are new coverage finding new
defects**: 4233 of the 4321 co-simulated rows pass outright, 86 are divergences
a SAT miter proved to be simulation artefacts, and the two real ones are
`cva6_hpdcache_subsystem` (2 diverging cycles) and `cva6_hpdcache_wrapper` (3)
at the HPDcache flavour of CVA6 -- modules that are `dead` at the default
configuration and were measured for the first time this week, `read_slang`
clean on both.  `read_slang`, measured on the same rows under the same
stimulus, diverges on 113.  The table is 430 rows larger than 2026-10-20: the
three CVA6 flavours add 429 rows and the sv-tests corpus moved by one.

The 14 divergences the 2026-10-19 table carried were closed in five days, and
each cause is worth keeping because none of them was what the symptom
suggested:

* **11 of the 14 were ONE defect**, counted twice because two families vendor
  the same RTL: VeeR EL2's six ICCM / DCCM / I-cache memory wrappers
  (`EL2_IC_DATA` 171 diverging cycles, `EL2_IC_TAG` 280, `el2_ifu_ic_mem` 284,
  `el2_ifu_iccm_mem` 300, `el2_lsu_dccm_mem` 300, `el2_mem` 300) and the same
  five again as caliptra-ss's `css_mcu0_*`.  An interface-member bit-select was
  answered by a module-level local of the SAME NAME, turning
  `dccm_bank_dout[i][..] = dccm_mem_export.dccm_bank_dout[i]` into a
  self-assignment, so the read data never left its reset value (#1258).  A
  self-assignment still builds a structurally valid netlist that `check`
  reports clean, so the test for it asserts the CONNECTION, not a cell count.
* **TNoC `tnoc_packet_serializer`** (189) was **not ours**.  Our netlist held
  the module's multi-flit header arm while `read_slang` held the single-flit
  one, and Surelog's own elaborated model held only the multi arm.  A constant
  function's `if` / `return` over a struct FORMAL never folded, so
  `HEADER_FLITS` had no value when the generate-if was evaluated -- and that
  if-generate takes the else branch whenever it cannot evaluate the condition,
  silently.  Fixed upstream (chipsalliance/UHDM#1166,
  chipsalliance/Surelog#4221), which closed `tnoc_packet_deserializer` and
  `tnoc_error_checker` with it.
* **RSD `PerformanceCounter`** (228) was a regression we introduced on
  2026-10-19 and fixed the same day: #1249's staged in-flight path had started
  answering single-level struct field reads while the write side of those
  compound assignments kept resolving the field its own way, so the two stopped
  agreeing.  Guarding it to genuinely nested fields restored the row (#1257).
* **sv-tests `chapter-10/10.6.2--force-release.sv`** uses `force` / `release`,
  which has no synthesis semantics on either side: Verilator honours the force
  on the RTL and no netlist can represent it, so the divergence measures the
  corpus.  The sweep had no adjudication list at all, unlike every other
  sweep, so it now reads one (#1261).

Everything that used to be on this list is gone: RgGen's four `differs` rows
(`rggen_mux`, `block_0`, `block_1`, `uart_csr`) are all proven and co-sim
clean, so the family is **25 / 25**; RSD's multi-write-port RAMs
(`BlockMultiPortRAM`, `RegisterMultiPortRAM`, `BlockTrueDualPortRAM`), its
`FPExecutionStage` / `FP32PipelinedOther` pair and cvw's carry-less-multiply
cluster (`clmul`, `zbc`, `bitmanipalu`, `alu`) all pass; and Pavona's two full
chips lower and co-simulate.

The 76 `read_slang` divergences are listed with their
reasons in [docs/slang_unsupported.md](docs/slang_unsupported.md).  Counted by
[`test/sweep_table.py`](test/sweep_table.py) over the reports of the runs below — nothing in this
table is kept by hand.

Numbers above are the **2026-10-22 nightly runs**, one per sweep workflow, 18
workflows.  Every nightly ran that morning on main at `f65702a6c`, which is
the tree with the CVA6 flavour sweep (#1267) in it, so the three flavour
families appear for the first time.  Two rows are not from that morning:
**BlackParrot is its 2026-10-18 run** on `52374ad92` (its nightly has been
cancelled on the job time limit every day since, and a cancelled run uploads a
TRUNCATED report, 95 of its 126 rows), and the **External IP** row mixes the
2026-10-22 ext dispatch on `f9d32e2d0` (run 39854252763: axi, common_cells,
cv32e40p, hdmi, verilog-pcie, the XiangShan library) with the 2026-10-20 ext
run (39396603819: caliptra-ss, cve2, cvfpu, cvw, verilog-ethernet), because
the 10-22 dispatch was still publishing those families when the table was
taken -- their 10-20 and 10-22 numbers are identical for every family both
runs had finished.  The **OpenTitan IP library** (#1268, 605 modules) has no
nightly yet and is not in this table; its first dispatch is the same run
39854252763, still running at the time of writing.  Run ids: ibex
39741501672, rp32 39744204814, fx68k 39784956558, scr1 39743766501, rggen
39790604505, veer-eh1 39751125305, tnoc 39792360831, veer-el2 39763829282,
rsd 39756486232, black-parrot 39126191261, opentitan 39777587456, pavona
39751517757, cva6 39748696611, cva6-flavours 39756605918, caliptra
39761257260, xiangshan-core 39757172255, sv-tests 39751418334.

- **CVA6's 5 `differs` rows are adjudicated non-defects**, each re-checked on
  2026-10-19 against its own counterexample: `hpdcache_cmo` is a
  **unique-case violation** (the solver sets `is_flush_by_nline`,
  `is_flush_all` and `is_fence` at once, so two arms of
  `unique case (1'b1)` match and either lowering is licensed);
  `hpdcache_uncached` is **unprovable by construction** -- the differing bit
  is in `mem_req_atomic`, which that `always_comb` never assigns on the path
  taken, and BOTH netlists then hold it through the same combinational
  self-hold, which SAT reads as two independent free values;
  `csr_regfile` is an **init-state** difference, because we fold `dcsr`'s
  reset-only `xdebugver` field to a constant while `read_slang` keeps a flop
  and the miter's `-set-init-zero` pins both initial states to 0;
  `macro_decoder` and `zcmt_decoder` are **latch-vs-self-feedback** -- we
  infer a latch for a comb variable the source leaves unassigned on the
  illegal-instruction path (22 and 5 of them) where `read_slang` builds a
  combinational loop SAT treats as free.  Every undriven row is a net the
  source never assigns, which the sweeps tell apart from a dropped driver.
- **rp32's driver conflicts are gone**: the 32-conflict rows (sibling generate
  scopes sharing a name) no longer appear — all 13 modules report none, so the
  formal column is trustworthy again.  Of the 13, 6 are proven and 7 have no
  `read_slang` reference to compare against.
- **External IP: 74 rows are still not comparable, down from 435** (and the
  cvw figure is now 174 proven of 193 comparable, 27 of 220 not comparable).
  Six project-setup fixes did that — binding cvw's configuration struct (234
  rows comparable for the first time), wrapping away an interface port at
  the top (39 rows), retrying a module at parameters its own design permits
  rather than at zero-defaults, and supplying a header the repository never
  vendored.  They also settled nine axi rows that had been reporting `differs`
  with undriven nets: those were compared in a degenerate configuration, so the
  findings were never real.
- **VeeR EL2's six memory wrappers are the clearest case for harness changes
  that make rows FAIL.** Until the 2026-10-15 nightly all six read
  `elab-fail — (no elaboration)` and contributed nothing to any column; once
  the harness elaborated them they each showed a 171-300 cycle divergence, and
  the same five showed it again inside caliptra-ss, which vendors that core —
  11 of the 14 divergences in the 10-19 table, one defect counted twice.  They
  were failing all along, unmeasured.  #1258 fixed the interface-member select
  behind all of them and every one of the 11 now co-simulates clean.
- **Still open on our side:** the sweep rows where `read_slang` tracks the RTL and
  we do not are listed, in the same format as slang's own failures, in the "other
  direction" section of [docs/slang_unsupported.md](docs/slang_unsupported.md).
- CVA6 is the one family excluded from the local `--no-cva6` developer run, so
  read the nightly rather than a local run for its figures.

**Pavona vs upstream OpenTitan** are swept separately on purpose: pavona is a
hard *fork* whose RTL has diverged — of the 120 files the two trees share,
only **66 are byte-identical** (`kmac_app.sv` differs by 1531 lines) — so a
pavona verdict is not an upstream verdict.  OTBN does not exist in pavona at
all, so every OpenTitan row is new coverage.

#### External IP families

Scores are over **comparable** modules — a module whose own default parameters
do not give a legal elaboration, or that `read_slang` cannot read, has no
reference to be judged against and is excluded rather than counted as a
failure.  `undriven` likewise counts comparable rows only.

| Family | Upstream repo | Commit | Proven | Not comparable | Undriven |
|---|---|---|---|---|---|
| PULP AXI | [pulp-platform/axi](https://github.com/pulp-platform/axi) | [`70b8e54f`](https://github.com/pulp-platform/axi/commit/70b8e54fd460) | **88 / 100** | 8 of 108 | 0 (`axi_lfsr` and `axi_lite_lfsr` carry 64 bits each the source never assigns — an unconnected `data_i` on the read-side LFSR — reported as such, not as dropped drivers) |
| PULP common_cells | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) | [`121182ea`](https://github.com/pulp-platform/common_cells/commit/121182eaa0fa) | **120 / 120** | 0 of 120 | 0 |
| OpenHW CVE2 | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | [`d079e8c8`](https://github.com/openhwgroup/cve2/commit/d079e8c8e6a0) | **17 / 21** | 2 of 23 | 0 |
| OpenHW CV32E40P | [openhwfoundation/cv32e40p](https://github.com/openhwfoundation/cv32e40p) | [`6033d2b1`](https://github.com/openhwfoundation/cv32e40p/commit/6033d2b1be32) | **21 / 26** | 0 of 26 | 0 |
| OpenHW CVFPU | [openhwfoundation/cvfpu](https://github.com/openhwfoundation/cvfpu) | [`77811635`](https://github.com/openhwfoundation/cvfpu/commit/77811635cb7e8649f1d9484733ee6a0bdb44a0e6) | **13 / 19** | 1 of 20 | 0 (`control_mvp` and its parents: 4 bits the source never assigns) |
| OpenHW CORE-V Wally | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | [`bc7012a9`](https://github.com/openhwgroup/cvw/commit/bc7012a92273) | **174 / 193** | 27 of 220 | 0 |
| hdl-util HDMI | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | [`83b1c954`](https://github.com/hdl-util/hdmi/commit/83b1c9543a91) | **8 / 9** | 2 of 11 | 0 |
| verilog-ethernet | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | [`77320a94`](https://github.com/alexforencich/verilog-ethernet/commit/77320a9471d1) | **107 / 112** | 17 of 129 | 0 (`xgmii_interleave` bit 72 is never assigned in the source) |
| verilog-pcie | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) | [`25156a9a`](https://github.com/alexforencich/verilog-pcie/commit/25156a9a162c) | **75 / 89** | 4 of 93 | 0 |
| XiangShan XS-Verilog-Library | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) | [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | **19 / 21** | 0 of 21 | 0 |
| Caliptra subsystem | [chipsalliance/caliptra-ss](https://github.com/chipsalliance/caliptra-ss) | [`dfa6c631`](https://github.com/chipsalliance/caliptra-ss/commit/dfa6c631dbfc) | **242 / 260** | 13 of 273 | 0 |

**How the reference frontend itself does.** The left-most column of every sweep
table co-simulates the `read_slang` netlist against the same RTL, so the sweeps
also measure the frontend they compare against.  Every row where it does not
track the RTL -- and every design it cannot read at all, in the sweeps, in the
local test suite and in the upstream Yosys tests -- is collected in ONE report,
[docs/slang_unsupported.md](docs/slang_unsupported.md): one format (reason, link
to the test, recipe to reproduce), the recipes described up front.  Rows the
harness could not give slang a fair run on (a module no file of the test defines,
a test invalid on purpose, a design no frontend elaborates, a co-sim both netlists
fail identically) are in [docs/incomplete_testcases.md](docs/incomplete_testcases.md)
with a statement of which frontends fail on them.  The same report lists the
**other direction** -- rows where `read_slang` is clean and OURS is wrong --
because a document that can only record another tool's mistakes is not a
measurement.

**What the reference frontend cannot read.** 117 sweep rows carry
`no reference (read_slang fails)` -- `read_slang` cannot elaborate the module,
so there is nothing for the miter or the co-sim to judge us against -- and of
the 76 rows where it does build a netlist that diverges from the RTL, **19 are
rows ours passes outright**.  The other 55 are rows where both netlists diverge
and a miter has adjudicated ours as the same simulation artefact, which is the
shared-divergence class rather than a verdict on either frontend.  Every one of
these is in [docs/slang_unsupported.md](docs/slang_unsupported.md) with the
reason, a link to the module's source and the recipe that reproduces it, next
to the local and upstream tests slang cannot read.  Rows that carry no verdict
for either side -- a design neither frontend elaborates, a co-sim both netlists
fail identically, a testbench Verilator could not build -- sit in
[docs/incomplete_testcases.md](docs/incomplete_testcases.md) with a statement of
which frontends fail on them.  The unreadable count was **360** on 2026-09-29: an
audit of every class found that a configuration the design forbids at its own
defaults, a package or macro our closure withheld, an interface port nobody
wrapped, an unroll limit left at its default and a header the repository never
vendored accounted for 234 of them -- harness, not slang -- and fixing the
harness is what brought the number down.

#### Generated IP: the XiangShan core

XiangShan's core is **Chisel/Scala** — the repository contains no Verilog, so
unlike every other family there is nothing to read until the generator has run.
The generator does not fit a hosted runner (`DefaultConfig` needs a 40 GB JVM
heap for 3.2 M lines), so the nightly `xiangshan-core-full` family (its own workflow, `sweep-xiangshan.yml`) fetches the
generator's **output** instead: the release asset
[`xiangshan-rtl-e4566c29`](https://github.com/alainmarcel/uhdm2rtlil/releases/tag/xiangshan-rtl-e4566c29)
is `build/rtl` of `make verilog CONFIG=DefaultConfig` at XiangShan `e4566c29`
(firtool 1.149.0, 13 MB compressed), with its provenance note.  firtool emits
one concrete module per file, so a generated module *is* its instantiation:
sweeping every file sweeps every module of the core with the parameters it has
under `XSTop`; it is its own nightly (`sweep-xiangshan.yml`, 16 shards of ~125 modules), not part of the external-IP breadth sweep.

Each module is read with its own dependency closure.  Surelog's memory grows
with that closure (~0.25 GB per MB of this RTL, 35.5 GB on `XSTop`), so the
manifest caps it at 16 MB: 1994 of the 2002 modules fit a 16 GB runner, and
the 8 top-level blocks (`XSTop`, `XSTile`, `XSCore`, `Backend`, `CtrlBlock`,
`MemBlock`, `Frontend`, `Rob`) are reported as skipped rather than taking a
shard down.  To sweep those, or to regenerate the RTL, use a workstation:

```bash
make xiangshan-core-full       # the CI family: fetch the published RTL, sweep every module
make xiangshan-core-full-gen   # generate locally (mill + firtool, 40 GB JVM heap), 42 hand-picked blocks incl. XSTop
make xiangshan-core            # CONFIG=MinimalConfig, generated locally
```

The generating targets clone `OpenXiangShan/XiangShan` at the pinned commit
under `$EXT_IP_ROOT` (default `~/ext`), download `mill` if needed and run
`make verilog`; a JDK 17+ is their only prerequisite.  The hand-written
**XS-Verilog-Library** (the `xiangshan` family above) is swept nightly as well.

AXI additionally pulls [tech_cells_generic](https://github.com/pulp-platform/tech_cells_generic)
and verilog-pcie pulls [verilog-axis](https://github.com/alexforencich/verilog-axis).

AXI's exclusions are one cause: PULP declares its struct ports through type
parameters (`parameter type axi_resp_t = logic`), so a module swept standalone
with its defaults performs a member access on a 1-bit `logic` — not legal
SystemVerilog, and nothing to compare against.  The manifest's `bind` section
gives those modules concrete types and values instead, which is what took the
family from 73 excluded rows to 32; the rest are recorded with the slang
diagnostic that identifies them.

**CORE-V Wally sweeps 234 modules.**  Its nightly job used to take the whole
runner down: one module (`fdivsqrtuslc4`, 113 lines that fill a 1024-entry table
from a nested loop) made `read_uhdm` peak at 10.5 GB, and at `--jobs 2` on a
16 GB runner the VM was exhausted before any per-process cap could trip.  Both
halves are fixed — the blowup itself was a quadratic expansion in loop
unrolling, now 0.37 GB — so the family reports real rows again.


### SystemVerilog Frontend Comparison

The 4-frontend regression matrix (`make test-matrix`, run nightly) synthesizes
every test's SystemVerilog through **four** frontends and ranks them by how much
SV each handles **correctly**. Every netlist is verified either by **formal
equivalence** — Yosys `equiv_induct` plus a sound SAT-from-reset miter, against
the Yosys Verilog-frontend golden — **and/or** by **high-activity randomized
Verilator co-simulation** against the original RTL. A result counts as *Correct*
only when one of those checks proves it equivalent; *SV-only* means the frontend
synthesized SystemVerilog that the native Verilog frontend cannot even read (no
golden to compare against, so it is verified against the RTL by co-simulation).

The nightly run
([Frontend Matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml),
1822 tests) reports two things separately: what each frontend could **read**,
and — where a `read_verilog` golden exists to compare against — whether it was
**right**.

| Frontend | Read | Failed to read | Correct | Incorrect | No golden | Unknown |
|---|---:|---:|---:|---:|---:|---:|
| **`uhdm`** (this project) | **1792** | 33 | 1044 | 24 | 654 | 67 |
| `sv2v` | 1610 | 213 | 992 | 0 | 546 | 71 |
| `slang` (Yosys sv-elab) | 1545 | 277 | 845 | 0 | 569 | 131 |
| `verilog` (Yosys native, the golden) | 1091 | 731 | 1091 | 0 | — | 0 |

*Failed to read* = failed + crashed + timed out + out-of-memory.  *No golden* = this
frontend synthesized but `read_verilog` could not, so there is nothing to
compare against — a capability win, verified against the RTL by co-simulation
rather than formally.  *Unknown* = formal non-equivalence the co-sim could not
adjudicate.

On this corpus the UHDM frontend reads the most SystemVerilog — **1792 of 1822**,
including **654 designs the native Verilog frontend cannot read at all**.

**How to read this table honestly:**

- **It is a self-run benchmark on a largely self-authored corpus.** The matrix is
  mostly this project's own test suite (plus imported Yosys and
  chipsalliance/UHDM-integration tests), and many tests were added specifically to
  exercise constructs this frontend targets. The ranking is real but it is *not* a
  neutral third-party comparison — a tool graded on the set its authors curated is
  playing at home. Read "#1 by ~10 points" in that light.
- **The benchmark rewards breadth over conservatism.** `sv2v` and `slang` report
  **0 incorrect** results here; `uhdm`'s **24** are a real (tracked) triage backlog
  in `test/failing_tests.txt`. Ranking by how much is read favors breadth, but
  "accepts less yet is never wrong on what it accepts" is a legitimate — sometimes
  preferable — posture, and it's the one `sv2v`/`slang` show on this corpus. Their
  higher "Failed to read" counts (213 / 277 vs 33) reflect that trade-off, not a
  defect.
- **Coverage ≠ ecosystem fit.** `slang`/sv-elab is the frontend that has been
  **upstreamed into Yosys itself**, ships in the OSS CAD Suite, and is used by
  OpenROAD — adoption, integration, and maintenance advantages a nightly coverage
  count does not capture. If your criterion is *maximum SV coverage through the
  Surelog/UHDM path today*, this table favors `uhdm`; if it is *what is maintained
  and integrated for production*, sv-elab has the stronger case. Both can be true.

`verilog` is the golden reference, so it has no *SV-only* column and its ceiling is
the SV subset it can parse. Numbers are from one nightly run and drift between runs
(seq-equiv induction is inductively incomplete on some designs) — treat any single
figure as approximate.

> **Note:** 349 DUTs from
> [chipsalliance/UHDM-integration-tests](https://github.com/chipsalliance/UHDM-integration-tests)
> were imported as `test/<Name>/dut.sv` (harnesses excluded) on 2026-06-14, when only
> 89 of the 316 observable ones passed; `test/imported_tests_status.txt` keeps that
> initial assessment.  Most of the gaps it lists (parameters, functions, arrays,
> patterns, structs, enums) have since been closed — the 24 `uhdm` *Incorrect* tests
> above are what remains of that backlog and are tracked in `test/failing_tests.txt`.

The detailed per-test coverage that used to follow — the **UHDM-only verified
test list**, **Recent Additions**, and the **Recent Fixes** changelog — has moved
out of the README to keep this section focused on the leaderboard:

- Changelog / fixes → [`docs/recent-improvements.md`](docs/recent-improvements.md)
- Test catalog (incl. the UHDM-only list) → [`docs/test-cases.md`](docs/test-cases.md)
- chipsalliance/sv-tests (the LRM-chapter corpus, 707 synthesis tests of its own local suite, swept nightly by the **Sweep sv-tests** action): read_uhdm 688 pass vs read_verilog 364 / read_slang 682, every miss classified → [`docs/sv_tests_coverage.md`](docs/sv_tests_coverage.md)
- Everything `read_slang` cannot read or gets wrong, across the sweeps, the 1341 internal tests and the 576 generated upstream Yosys tests, with reproduce recipes → [`docs/slang_unsupported.md`](docs/slang_unsupported.md); tests no frontend can be judged on → [`docs/incomplete_testcases.md`](docs/incomplete_testcases.md)

## Architecture & Workflow

```
SystemVerilog (.sv) → [Surelog] → UHDM (.uhdm) → [UHDM Frontend] → RTLIL → [Yosys] → Netlist
```

### Components

#### 1. **Surelog** (`third_party/Surelog/`)
- Industry-grade SystemVerilog parser and elaborator
- Handles full IEEE 1800-2017 SystemVerilog standard
- Outputs Universal Hardware Data Model (UHDM)
- Provides semantic analysis and type checking

#### 2. **UHDM Frontend** (`src/frontends/uhdm/`)
- **Core Module** (`uhdm2rtlil.cpp`) - Main frontend entry point, design import, and UHDM elaboration
- **Module Handler** (`module.cpp`) - Module definitions, ports, instances, and wire declarations
- **Process Handler** (`process.cpp`) - Always blocks, procedural statements, and control flow
- **Expression Handler** (`expression.cpp`) - Operations, constants, references, and complex expressions
- **Functions Handler** (`functions.cpp`) - Compile-time constant function evaluation
- **Interpreter** (`interpreter.cpp`) - Statement interpreter for initial block execution
- **Memory Handler** (`memory.cpp`) - Memory inference and array handling
- **Memory Analysis** (`memory_analysis.cpp`) - Advanced memory pattern detection and optimization
- **Clocking Handler** (`clocking.cpp`) - Clock domain analysis and flip-flop generation
- **Package Support** (`package.cpp`) - SystemVerilog package imports, parameters, and type definitions
- **Primitives Support** (`primitives.cpp`) - Verilog primitive gates and gate arrays
- **Reference Module** (`ref_module.cpp`) - Module instance reference resolution and parameter passing
- **Interface Support** (`interface.cpp`) - SystemVerilog interface handling with automatic expansion

#### 3. **Yosys** (`third_party/yosys/`)
- Open-source synthesis framework
- Processes RTLIL for optimization and technology mapping
- Provides extensive backend support for various FPGA and ASIC flows

### Supported SystemVerilog Features

- **Module System**: Module definitions, hierarchical instantiation, parameter passing
- **Data Types**:
  - Logic, bit vectors, arrays
  - Packed multidimensional arrays with dynamic element access (e.g., `logic [0:3][7:0]`, typedef variants)
  - Packed structures with member access via bit slicing
  - Packed unions with member access (all members overlay at bit offset 0, width = widest member)
  - Structs containing unions and unions containing structs (nested access)
  - Struct arrays with complex indexing
  - Package types and imports
- **Procedural Blocks**: 
  - `always_ff` - Sequential logic with proper clock/reset inference
  - `always_comb` - Combinational logic
  - `always` - Mixed sequential/combinational logic
- **Expressions**:
  - Arithmetic, logical, bitwise, comparison, ternary operators
  - Compound assignment operators (`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `<<<=`, `>>>=`)
  - Increment/decrement operators (`x++`, `--x`) as statements and in expressions
  - Assignment expressions (`x = (y = expr) + 1`) with proper side-effect ordering
  - System function calls ($signed, $unsigned, $floor, $ceil)
  - User-defined function calls with good support (simple functions, arithmetic, boolean logic, case statements, nested if-else)
  - Struct member access (e.g., `bus.field`)
  - Hierarchical signal references
  - Parameter references with HEX/BIN/DEC formats
  - Loop variable substitution in generate blocks
- **Control Flow**: If-else statements, case statements (including constant evaluation in initial blocks), for loops with compile-time unrolling and variable substitution, repeat loops with compile-time unrolling, while loops in compile-time function evaluation, named and unnamed begin blocks with local variable scoping
- **Memory**: Array inference, memory initialization, for-loop memory initialization patterns, asymmetric port RAM with different read/write widths
- **Shift Registers**: Automatic detection and optimization of shift register patterns (e.g., `M[i+1] <= M[i]`)
- **Generate Blocks**: 
  - For loops with proper scope handling
  - If-else generate conditions
  - Hierarchical naming (e.g., `gen_loop[0].signal`)
  - Net and variable imports from generate scopes
- **Packages**: Import statements, package parameters (including localparam/parameter from enum constants), package-scoped typedefs and enum types, struct types, functions
- **Net Types**: `wand` and `wor` (wire-AND and wire-OR) with proper multi-driver resolution
- **Primitives**: Gate arrays (and, or, xor, nand, nor, xnor, not, buf)
- **Types & Casts**: enums (incl. ranged members and enum arrays), typedef chains, unpacked
  arrays and unpacked-array ports, unions, type parameters, size / type casts, `$bits`,
  `$clog2`, assignment patterns (`'{a: .., default: ..}`) on structs and packed arrays
- **Statements**: `unique` / `priority` case, `case inside`, tasks and void functions,
  `break` / `return` in unrolled loops, cross-module (XMR) reads and writes
- **Advanced Features**: 
  - Interfaces with modports, interface arrays and interface-typed ports
    (flattened to individual signals)
  - Interface port connections and signal mapping
  - Assertions (`assert property` lowered to `$check` cells)

## Quick Start

**Version.** The project version tracks the Yosys release it is built against — `project(uhdm2rtlil VERSION 0.70)` for Yosys 0.70.  A plugin is only ever loaded by the Yosys it was compiled for, so a single number names the pairing.

### Prerequisites
- GCC ≥ 11 (C++20; the bundled Yosys v0.70 and its built-in `read_slang` frontend require it)
- CMake **3.28 – 3.31** (≥ 3.28 for the bundled slang library; CMake 4.x is rejected by
  Surelog/UHDM's capnproto — `pip install 'cmake==3.31.6'` on ubuntu-22.04)
- Python 3.8+
- Standard development tools (make, bison, flex)
- Verilator (used by `test/test_sim_equivalence.py` to co-simulate
  the original SV against the UHDM-derived netlist for tests where
  the Yosys Verilog frontend can't parse the source — see
  [Verilator-based simulation equivalence](#verilator-based-simulation-equivalence-check) below)

On Debian / Ubuntu:
```bash
sudo apt-get install -y \
    build-essential cmake git python3 python3-pip pkg-config \
    libssl-dev zlib1g-dev libtcmalloc-minimal4 uuid-dev tcl-dev \
    libffi-dev libreadline-dev bison flex libfl-dev libunwind-dev \
    libgoogle-perftools-dev ccache help2man
```

`test/test_sim_equivalence.py` needs **Verilator 5.x** (5.020+) for SVA
parsing.  Ubuntu 24.04's stock `verilator` package is recent enough;
on older distros (22.04 ships 4.038) build from source:

```bash
git clone --depth=1 -b v5.048 https://github.com/verilator/verilator.git
cd verilator
autoconf
./configure --prefix=/usr/local
make -j$(nproc)
sudo make install
verilator --version  # confirm: "Verilator 5.048 ..."
```

### Build
```bash
# Clone with submodules
git clone --recursive https://github.com/alainmarcel/uhdm2rtlil.git
cd uhdm2rtlil

# Configure git hooks (prevents committing files >10MB)
git config core.hooksPath .githooks

# Build everything (Surelog, Yosys, UHDM Frontend)
make
```

### Basic Usage

The plugin (`uhdm2rtlil.so`) registers two Yosys commands for getting
SystemVerilog into RTLIL:

| Command | Input | Surelog run | Intermediate `.uhdm` |
|---------|-------|-------------|----------------------|
| **`read_sv`**   | SystemVerilog source(s) + Surelog flags | in-process | no — fully in-memory |
| **`read_uhdm`** | a pre-generated `.uhdm` file             | separate / earlier | yes |

#### `read_sv` — compile SystemVerilog directly (recommended)

Runs the Surelog compiler **in-process** and imports the elaborated in-memory
UHDM design straight to RTLIL, without writing or re-reading a `.uhdm` file.
All arguments are forwarded to Surelog verbatim, exactly as if it were the
`surelog` executable:

```bash
./out/current/bin/yosys -m uhdm2rtlil.so \
  -p "read_sv -parse -nobuiltin design.sv; synth -top top_module"

# Multi-file / flags work just like the surelog CLI:
#   read_sv -parse -nobuiltin a.sv b.sv +incdir+inc -DWIDTH=8 -top mytop
```

`read_sv` forces parse + elaborate + in-memory UHDM elaboration on and `.uhdm`
file writing off.  Pass any Surelog flag as usual; `-nobuiltin` is recommended
to skip Surelog's built-in classes.  Plugin-only options (consumed, not passed
to Surelog): `-uhdm_debug`, `-formal`, `-keep_names`, `-allow-undefined-modules`.

#### `read_uhdm` — read a pre-generated UHDM file

Useful when the UHDM database was produced by a separate Surelog run (e.g. the
test workflow, or for caching/debugging the `.uhdm`):

```bash
# Step 1: Generate UHDM from SystemVerilog
./build/third_party/Surelog/bin/surelog -parse -d uhdm design.sv

# Step 2: Read the UHDM file with the frontend
./out/current/bin/yosys -m uhdm2rtlil.so \
  -p "read_uhdm slpp_all/surelog.uhdm; synth -top top_module"
```

Options: `-debug`, `-formal`, `-keep_names`, `-allow-undefined-modules`.  An
instance of a module that has no definition is REFUSED by default, with the
modules named (Surelog only warns and would hand over an empty cell); the flag
keeps such instances as blackbox cells for a design read file by file, which
is what `read_verilog` does.

#### Using the test workflow
```bash
cd test
bash test_uhdm_workflow.sh simple_counter
```

## Testing Framework

### Test Structure
Each test case is a directory containing:
- `dut.sv` - SystemVerilog design under test
- Automatically generated comparison files:
  - `*_from_uhdm.il` - RTLIL generated via UHDM path
  - `*_from_verilog.il` - RTLIL generated via Verilog path
  - `rtlil_diff.txt` - Detailed RTLIL comparison
  - `*_from_uhdm_synth.v` - Gate-level netlist via UHDM path
  - `*_from_verilog_synth.v` - Gate-level netlist via Verilog path
  - `netlist_diff.txt` - Gate-level netlist comparison

### Running Tests
```bash
# Smoke-test the read_sv command (in-process Surelog compile, no .uhdm file).
# Verifies read_sv == Verilog frontend and that no .uhdm is written.  Fast;
# CI runs this first, and `make test` runs it as part of the suite.
make test-read-sv

# Run internal tests only (our test suite; includes test-read-sv)
make test

# Run all tests (internal + Yosys tests)
make test-all

# Run only the core IP tests (rp32 RISC-V SoC + lowRISC Ibex)
make test-cores

# Run Yosys tests only
make test-yosys

# The developer regression (what every PR runs locally): 6-way parallel,
# internal suite + slang miters + Verilator sim-equiv, CVA6 excluded
cd test && ./run_parallel.sh 6 --no-cva6

# Per-IP nightly sweeps (formal vs read_slang + opt-check + Verilator co-sim):
cd test && python3 core_sweep.py ibex        # ibex | rp32 | cva6 | pavona | tlul | aes | ... | egret | dragonfly | caliptra

# Run specific test from test directory
cd test
bash test_uhdm_workflow.sh simple_counter

# Run tests with options from test directory
cd test
bash run_all_tests.sh                    # Run internal tests only
bash run_all_tests.sh --all              # Run all tests (internal + Yosys)
bash run_all_tests.sh --cores            # Run only rp32 + Ibex core IP tests
bash run_all_tests.sh --yosys           # Run all Yosys tests
bash run_all_tests.sh --yosys add_sub   # Run specific Yosys test pattern

# Test output explanation:
# ✓ PASSED - UHDM and Verilog frontends produce functionally equivalent results
# ⚠ FUNCTIONAL - Works correctly but with RTLIL differences (normal and expected)
# ✗ FAILED - Significant functional differences or equivalence check failure

# The test framework performs multiple levels of comparison:
# 1. RTLIL comparison - Shows implementation differences
# 2. Synthesis and formal equivalence check - Uses Yosys equiv_make/equiv_simple/equiv_induct
# 3. Validates functional equivalence even when gate counts differ
```

### Yosys Test Integration

The UHDM frontend can run the full Yosys test suite to validate compatibility:

```bash
# Run all Yosys tests
make test-yosys

# Run specific Yosys test directory
cd test
./run_all_tests.sh --yosys ../third_party/yosys/tests/arch/common

# Run specific Yosys test
./run_all_tests.sh --yosys ../third_party/yosys/tests/arch/common/add_sub.v
```

### Verilator-based Simulation Equivalence Check

UHDM-only tests have no Yosys-Verilog-frontend reference netlist to formally
equivalence-check against, so `run_all_tests.sh` invokes
`test/test_sim_equivalence.py` on them as a soft warning.

The script co-simulates two views of the same design under Verilator:

  - **RTL form**  — the original `dut.sv`, simulated directly by Verilator
  - **Netlist**   — UHDM frontend output, post-`synth -auto-top`

A small SystemVerilog testbench instantiates both side by side
(`dut_rtl` / `dut_netlist`), and a C++ driver advances clocks, holds
reset for a few cycles, then drives random inputs for ~50–200 cycles,
comparing every output every cycle.  Clocks and resets are extracted
from the netlist via the `extract_clocks_resets` Yosys plugin
(`build/extract_clocks_resets.so`).

A mismatch surfaces as a `⚠️ Verilator co-sim WARNING` line in the
test summary and does **not** flip the test to failed.  Per-test
output is written to `<test_dir>/sim_equiv.log`.

You can also run it standalone:
```bash
cd test
./test_sim_equivalence.py setundef
```

The Yosys test runner:
- Automatically finds self-contained Verilog/SystemVerilog tests
- Runs both Verilog and UHDM frontends on each test
- Performs formal equivalence checking when both frontends succeed
- Reports UHDM-only successes (tests that only work with UHDM frontend)
- Creates test results in `test/run/` directory structure

### Test Categories

The internal suite spans flip-flops & registers, counters, combinational/boolean/
arithmetic logic, multiplexers, multipliers & pipelines, state machines, functions,
scope & variable shadowing, arrays & memory, data types & structs, generate &
parameterization, module hierarchy & interfaces, and primitives.

**See [`docs/test-cases.md`](docs/test-cases.md) for the full annotated catalog.**

### Test Management

The test framework includes automatic handling of known failing tests:

```bash
# View known failing tests
cat test/failing_tests.txt

# Format: one test name per line, # for comments
```

**How it works:**
- Tests listed in `failing_tests.txt` are expected to fail
- The test runner (`run_all_tests.sh`) will still run these tests
- If all failures are listed in `failing_tests.txt`, the test suite passes with exit code 0
- This allows CI to pass while acknowledging known issues
- New unexpected failures will cause the test suite to fail

**Current Status:** see the authoritative figures under
[Verification Methodology → Test Suite Status](#test-suite-status). In short: the
internal SystemVerilog suite passes with 0 true failures / 0 crashes, and
`failing_tests.txt` documents the known expected-fail cases from the imported
upstream-Yosys suite (feature gaps, non-DUT techmap files, and equiv_induct
incompleteness that the SAT miter proves equivalent) — it is **not** empty.

### Important Test Workflow Note

The test workflow runs `proc` before `opt` to ensure proper process handling:
```tcl
hierarchy -check -top $MODULE_NAME
stat
proc    # Convert processes to netlists first
opt     # Then optimize
stat
write_rtlil ${MODULE_NAME}_from_uhdm.il
synth -top $MODULE_NAME
```

This prevents errors when synthesizing designs with generate blocks and multiple processes.

## Project Structure

```
uhdm2rtlil/
├── src/frontends/uhdm/          # UHDM Frontend implementation
│   ├── uhdm2rtlil.cpp          # Main frontend, design import, interface expansion
│   ├── module.cpp              # Module/port/instance handling  
│   ├── process.cpp             # Always blocks and statements
│   ├── expression.cpp          # Expression evaluation
│   ├── functions.cpp           # Compile-time constant function evaluation
│   ├── interpreter.cpp         # Statement interpreter for initial blocks
│   ├── memory.cpp              # Memory and array support
│   ├── memory_analysis.cpp     # Memory pattern detection
│   ├── clocking.cpp            # Clock domain analysis
│   ├── package.cpp             # Package support
│   ├── primitives.cpp          # Primitive gates
│   ├── ref_module.cpp          # Module references
│   ├── interface.cpp           # Interface declarations and modports
│   └── uhdm2rtlil.h           # Header with class definitions
├── test/                        # Test framework
│   ├── run_all_tests.sh        # Test runner (internal / --all / --yosys / --cores / --cva6)
│   ├── run_parallel.sh         # Sharded developer regression (the PR gate)
│   ├── test_uhdm_workflow.sh   # Individual test workflow
│   ├── test_equivalence.sh     # Formal equivalence checking script
│   ├── test_sim_equivalence.py # Verilator co-sim of RTL vs UHDM netlist
│   ├── netlist_cosim.py        # Per-instance / per-module co-sim harness used by the sweeps
│   ├── core_sweep.py           # Nightly IP sweeps (formal vs read_slang + opt-check + co-sim)
│   ├── run_frontend_matrix.py  # 4-frontend comparison matrix
│   ├── failing_tests.txt       # Known failing tests list (with verdicts)
│   ├── sim_equiv_warn_baseline.txt  # Sim-equiv ratchet baseline
│   ├── ibex/, rp32/, cva6_equiv/     # Imported cores (verbatim RTL + manifests)
│   ├── pavona_*_equiv/, pavona_chips/  # Pavona IP families and full chips
│   ├── caliptra_chip/          # Caliptra full-chip harness
│   └── */                      # Individual test cases
├── docs/                        # Sub-tables and changelogs (pavona_sweep.md, test-cases.md, ...)
├── third_party/                # External dependencies
│   ├── Surelog/               # SystemVerilog parser (includes UHDM)
│   └── yosys/                 # Synthesis framework (v0.70 + one fork patch, built with read_slang)
├── .github/workflows/         # ci.yml (PR gate), regression-sharded.yml, frontend-matrix.yml, sweep-*.yml
├── build/                     # Build artifacts
├── CMakeLists.txt            # CMake build configuration
└── Makefile                   # Top-level build orchestration
```

## Test Results

The authoritative, up-to-date figures live in one place —
[Verification Methodology → Test Suite Status](#test-suite-status) and the
[SystemVerilog Frontend Comparison](#systemverilog-frontend-comparison) leaderboard
— to avoid the numeric drift that comes from repeating counts in several sections.
Any single figure is from one nightly run and is approximate.

## Recent Improvements

The frontend has landed a large number of incremental SystemVerilog features and
bug fixes — unpacked-array ports, packed multidimensional arrays, packed unions,
struct-field-parameter dimensions, function-local arrays, for-loop unrolling, memory
inference, signedness/sign-extension, interfaces, techmap cells, and many more.

**The full, annotated changelog lives in**
**[`docs/recent-improvements.md`](docs/recent-improvements.md).**

## Development Workflow

### Adding SystemVerilog Support
1. **Identify UHDM Objects**: Determine which UHDM object types represent the feature
2. **Implement Import**: Add handling in appropriate `src/frontends/uhdm/*.cpp` file
3. **Map to RTLIL**: Convert UHDM objects to equivalent RTLIL constructs
4. **Add Tests**: Create test cases comparing UHDM vs Verilog frontend outputs
5. **Validate**: Ensure generated RTLIL produces correct synthesis results

### Development Setup

#### Git Hooks
The project includes Git hooks to maintain code quality:

```bash
# Enable Git hooks (one-time setup)
git config core.hooksPath .githooks

# What the hooks do:
# - Prevent commits of files larger than 10MB
# - Prevent commits of test/run/**/*.v files (generated test outputs)
```

### Debugging
```bash
# Enable debug output
export YOSYS_ENABLE_UHDM_DEBUG=1

# Run with verbose logging
./out/current/bin/yosys -p "read_uhdm -debug design.uhdm; write_rtlil output.il"
```

### Key Design Principles
- **Correctness**: Generated RTLIL must be functionally equivalent to Verilog frontend
- **Completeness**: Support full SystemVerilog feature set over time
- **Performance**: Efficient UHDM traversal and RTLIL generation
- **Maintainability**: Clear separation of concerns between different handlers

## Development Approach: AI-Assisted Implementation

This project is developed using an innovative AI-assisted approach with Claude (Anthropic's AI assistant). The development workflow leverages Claude's ability to understand and work with multiple file formats simultaneously:

### How It Works

1. **UHDM Text Analysis**: Claude analyzes the UHDM text output (from `uhdm-dump`) to understand the structure and relationships of SystemVerilog constructs as represented in UHDM.

2. **RTLIL Comparison**: The `.il` files generated by both the UHDM frontend and Verilog frontend are compared to identify differences and ensure functional equivalence.

3. **Iterative Development**: Claude can:
   - Read UHDM dumps to understand what objects need to be handled
   - Analyze RTLIL differences to identify missing functionality
   - Suggest and implement fixes based on the patterns observed
   - Test changes and iterate until the outputs match

### Example Workflow

```bash
# 1. Generate UHDM and dump it for analysis
./build/third_party/Surelog/bin/surelog -parse test.sv
./build/third_party/UHDM/bin/uhdm-dump slpp_all/surelog.uhdm > test.uhdm.txt

# 2. Generate RTLIL from both frontends
yosys -p "read_uhdm slpp_all/surelog.uhdm; write_rtlil test_uhdm.il"
yosys -p "read_verilog test.sv; write_rtlil test_verilog.il"

# 3. Claude analyzes:
# - test.uhdm.txt to understand UHDM structure
# - Differences between test_uhdm.il and test_verilog.il
# - Implements necessary handlers in the frontend code
```

### Benefits of This Approach

- **Rapid Development**: Claude can quickly identify patterns and implement handlers
- **Comprehensive Understanding**: AI can analyze complex relationships across multiple file formats
- **Systematic Coverage**: Each test case systematically expands SystemVerilog support
- **Quality Assurance**: Comparing against Yosys's Verilog frontend ensures correctness

This "vibe coding" approach has proven highly effective, enabling the implementation of complex SystemVerilog features like packages, interfaces, and generate blocks in a fraction of the traditional development time.

## Continuous Integration

GitHub Actions run four kinds of jobs (all on 16 GB GitHub-hosted runners, the
build cached by commit):

- **`ci.yml`** — the PR gate: builds Surelog, Yosys (+ `read_slang`) and the
  plugin, then runs the internal suite.
- **`regression-sharded.yml`** — the full `make test-all --all` suite plus the
  CVA6 per-module ratchet, split into 12 shards and merged into one report
  (every PR and nightly); the numbers under *Test Suite Status* come from it.
- **`frontend-matrix.yml`** — the nightly 4-frontend comparison behind the
  leaderboard above.
- **`sweep-{ibex,rp32,cva6,pavona,caliptra}.yml`** — the nightly per-IP sweeps
  (formal vs `read_slang`, opt-check, Verilator co-sim; sharded, memory-capped)
  whose tables feed the *Supported Core IP* rows and `docs/pavona_sweep.md`.

## Contributing

1. Fork the repository
2. Clone and set up git hooks:
   ```bash
   git clone --recursive https://github.com/yourusername/uhdm2rtlil.git
   cd uhdm2rtlil
   git config core.hooksPath .githooks
   ```
3. Create a feature branch
4. Add appropriate test cases
5. Ensure all tests pass (or update `failing_tests.txt` if needed)
6. Submit a pull request

**Note**: The repository has git hooks configured to prevent committing files larger than 10MB. This helps keep the repository size manageable. If you need to include large files, consider using Git LFS or adding them to `.gitignore`.

## License

See `LICENSE` file for details.

## Related Projects

- [Yosys](https://github.com/YosysHQ/yosys) - Open source synthesis suite
- [Surelog](https://github.com/chipsalliance/Surelog) - SystemVerilog parser
- [UHDM](https://github.com/chipsalliance/UHDM) - Universal Hardware Data Model
- [sv-elab / yosys-slang](https://github.com/povik/yosys-slang) and [slang](https://github.com/MikePopoloski/slang) - the `read_slang` frontend used as the formal reference for SV-only designs
- [sv2v](https://github.com/zachjs/sv2v) - SystemVerilog-to-Verilog converter, the third column of the frontend matrix
- [Verilator](https://github.com/verilator/verilator) - the co-simulation engine behind every co-sim result
- Verified IP: [Ibex](https://github.com/lowRISC/ibex), [rp32](https://github.com/jeras/rp32), [CVA6](https://github.com/openhwgroup/cva6), [Pavona](https://github.com/pavona/pavona), [Caliptra](https://github.com/chipsalliance/caliptra-rtl)
