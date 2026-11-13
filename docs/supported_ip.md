# Supported core IP

Real-world (System)Verilog IP swept end-to-end through the UHDM frontend, with
the measured result of every family.  Back to the [README](../README.md);
the co-simulation table per core and the comparison with `read_slang` are in
[benchmarking.md](benchmarking.md).  Two rows of the table below stand for a
whole sub-table of their own: the [Pavona per-IP table](pavona_sweep.md) and
the [external IP families](ext_ip.md).

## The families


Every row runs the same four checks: the `read_slang` netlist's own Verilator
co-sim against the RTL (the **baseline** — it says whether the RTL is even
co-simulable), formal equivalence read_uhdm vs `read_slang` (SAT miter from
reset), a structural opt-check for dropped drivers (undriven nets), and the
read_uhdm Verilator co-sim.  A SAT miter adjudicates every divergence, so a
proof gap is never mistaken for a bug.

| IP | Source | Scope | Result | Sweep |
|----|--------|-------|--------|-------|
| **Internal SystemVerilog suite** (this repository) | [`test/`](../test) -- 1864 hand-written and converted tests, incl. the 441 chipsalliance/sv-tests conversions in [`test/sv_tests`](../test/sv_tests) | Every reader construct the project has had to get right, one test each: the four-frontend matrix (read_uhdm vs `read_verilog` golden, read_slang miter, Verilator co-sim) plus 550 netlist-SHAPE gates; runs on every PR and nightly, not a sweep | **999 formally equivalent + 783 UHDM-only** (1782 / 1820 functional, 0 true failures) · 688 / 705 slang miters (17 known-fail, each reasoned) · 532 / 550 structural gates (18 known-fail) · 18 equivalence failures, all `equiv_induct`-caught, 0 miter escapes · 100 baselined co-sim divergences, 0 new -- main at `b4073a653`, run 41474238595 | [Regression](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml) · [docs/verification.md](verification.md) |
| **Ibex** | [lowRISC/ibex](https://github.com/lowRISC/ibex) | 2-stage RV32IMC core (+PMP, ICache, lockstep); 28 modules incl. `ibex_top` | **22 / 28 proven** · 20 / 24 co-sim, 0 `read_uhdm` divergences (4 adjudicated artefacts) · 28 / 28 opt-clean · 1 `differs` formal-only, 1 over the SAT budget, 4 no `read_slang` reference · `read_slang` itself diverges on none of its own (3 shared artefacts) | [ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) |
| **rp32 (R5P)** | [jeras/rp32](https://github.com/jeras/rp32) | 32-bit cores + TCB SoCs; 13 modules | **6 / 13 proven** · 3 / 7 co-sim, 0 divergences (4 adjudicated artefacts) · 13 / 13 opt-clean · 6 rows have no `read_slang` reference · both SoCs boot and run a program · `read_slang` diverges on none of its own (3 shared artefacts) | [rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) |
| **fx68k** | [ijor/fx68k](https://github.com/ijor/fx68k) @ [`0602ee46`](https://github.com/ijor/fx68k/commit/0602ee4627b10f301298f2673d826cdd6baa9327) (the commit chipsalliance/sv-tests pins) | Cycle-accurate **Motorola 68000** — the one non-RISC-V CPU core in the sv-tests list: sequencer, microcode/nanocode ROMs and their address PLA, ALU and shifter, bus arbiter/controller, exception unit; 22 modules from three files | **18 / 22 proven** · 6 / 10 co-sim, 0 divergences (4 adjudicated artefacts) · 21 / 21 opt-clean · 1 `differs` formal-only, 3 no `read_slang` reference · `read_slang` diverges on none of its own (6 artefacts of the 12 it co-simulates: 4 shared, 2 with no oracle) | [fx68k](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml) |
| **Syntacore SCR1** | [syntacore/scr1](https://github.com/syntacore/scr1) @ [`ebb5e355`](https://github.com/syntacore/scr1/commit/ebb5e3551a9d93c0ee95f0b767dd878b8927e702) | RV32IMC core, pipeline and the AXI/AHB SoC tops; 37 modules | **28 / 37 proven** · 36 / 37 co-sim, **1 `read_uhdm` divergence** (`scr1_core_top`: 152 of 300 cycles, read_slang clean, formal `differs` -- OPEN, the next lead) · 37 / 37 opt-clean · 2 `differs` formal-only · 7 over the SAT budget | [scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml) |
| **RgGen** | [rggen/rggen-sv-rtl](https://github.com/rggen/rggen-sv-rtl) @ [`6b3f25a0`](https://github.com/rggen/rggen-sv-rtl/commit/6b3f25a08fdbe87c6ab0bccbf83d9a16eb6974f7) + [rggen/rggen-sample](https://github.com/rggen/rggen-sample) @ [`9458b9ff`](https://github.com/rggen/rggen-sample/commit/9458b9ffd6d9bb5b4b23a0d66b55ae6c653e8012) (the commits chipsalliance/sv-tests pins) | Register-file generator: the hand-written library (bit fields and their counters/triggers, register and adapter commons, APB / AXI4-Lite / Avalon / Wishbone / native bridges, the address decoder, the mux and its recursive OR reducer) plus the generated sample blocks; 26 modules over two repos | **25 / 25 proven — the family is clean** · 25 / 25 co-sim, 0 divergences · 25 / 25 opt-clean · 0 `differs`, 0 over budget, 0 rows without a reference | [rggen](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml) |
| **VeeR EH1** | [chipsalliance/Cores-VeeR-EH1](https://github.com/chipsalliance/Cores-VeeR-EH1) @ [`d04b1c7a`](https://github.com/chipsalliance/Cores-VeeR-EH1/commit/d04b1c7ae675a63dc4307cacfd10547ec937b928) | RV32IMC core (`veer` / `veer_wrapper`), its IFU/DEC/EXU/LSU/DBG blocks, the `rv*` primitive library and the AHB/AXI4 bridges; 66 modules | **55 / 67 proven** · 66 / 66 co-sim, 0 divergences · 67 / 67 opt-clean · whole core `veer` equivalent + co-sim PASS · 0 undriven, 0 read errors · 11 over the SAT budget, 1 no reference | [veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml) |
| **TNoC** | [taichi-ishitani/tnoc](https://github.com/taichi-ishitani/tnoc) @ [`7e9841ff`](https://github.com/taichi-ishitani/tnoc/commit/7e9841ff775ea22fba3f222f7bdfe35668345e00) (the commit chipsalliance/sv-tests pins) | Network-on-chip: the fabric and its routers, input/output blocks and switches, the virtual-channel arbiter / merger / mux / splitter, the packet serializer and deserializer, the AXI master and slave adapters, over the `tbcm_*` basic-component library (a submodule); 43 modules | **18 / 43 proven** · 12 / 12 co-sim, **0 divergences** · 24 / 24 opt-clean · 0 `differs` · 25 rows have no `read_slang` reference (its interface-array ports) | [tnoc](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml) |
| **VeeR EL2** | [chipsalliance/Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) @ [`c2ea3a73`](https://github.com/chipsalliance/Cores-VeeR-EL2/commit/c2ea3a7382dd73ff8ff8c38f257382dfdd91be5e) (the commit chipsalliance/sv-tests pins) | RV32IMC core (`el2_veer_wrapper` / `el2_veer`), its IFU/DEC/EXU/LSU/DBG/PIC/PMP/DMA blocks, the lockstep shadow and the rv* primitive library; 91 modules (`rvclkhdr` excluded) | **77 / 91 proven** · 87 / 87 co-sim, **0 divergences** · 91 / 91 opt-clean, 0 undriven · 0 `differs`, 9 over budget, 5 no reference · `rvclkhdr` excluded (not compiled in the swept configuration) | [veer-el2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml) |
| **VeeR EH2** | [chipsalliance/Cores-VeeR-EH2](https://github.com/chipsalliance/Cores-VeeR-EH2) @ [`32bdfe24`](https://github.com/chipsalliance/Cores-VeeR-EH2/commit/32bdfe24c0194a5b625a70624144e4c6dec5f682) | Dual-threaded RV32IMC core (`eh2_veer_wrapper` / `eh2_veer`), its IFU/DEC/EXU/LSU/DBG/PIC/DMA blocks, the rv* primitive library and the AHB/AXI4 bridges; 100 modules (technology memory wrappers, `rvclkhdr` and the testbench reader excluded) | **81 / 100 proven** · 95 / 96 co-sim PASS, **0 `read_uhdm` divergences** (`eh2_ifu_mem_ctl`'s 150 cycles adjudicated by the miter as an artefact) · 100 / 100 opt-clean, 0 undriven · 15 over the SAT budget, 0 `differs`, 4 no reference · `read_slang` diverges on 2 of its own | [veer-eh2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh2.yml) |
| **RSD** | [rsd-devel/rsd](https://github.com/rsd-devel/rsd) @ [`7b65f6ba`](https://github.com/rsd-devel/rsd/commit/7b65f6ba) | Out-of-order superscalar RISC-V core (RV32IMF) — the `Core` sv-tests builds, its front end, rename / issue / commit stages, FP pipelines and cache hierarchy; 165 rows after its interfaces and test benches are set aside | **116 / 165 proven** · 139 / 140 co-sim, **0 divergences** (1 adjudicated artefact) · 144 / 144 opt-clean · 2 `differs` formal-only, 24 over the SAT budget, 23 no `read_slang` reference · `read_slang` diverges on 3 of its own (+1 shared artefact) | [rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml) |
| **BlackParrot** | [black-parrot/black-parrot](https://github.com/black-parrot/black-parrot) @ [`710b0ea9`](https://github.com/black-parrot/black-parrot/commit/710b0ea998c3b2f70ef9671d5619e439f13f826c) (the commit chipsalliance/sv-tests pins) | Linux-capable RV64 multicore (`wrapper` / `bp_processor`): the FE/BE/ME complexes, the CCE/LCE coherence engines, the bedrock network, over `basejump_stl` + `HardFloat` (three repos); 125 modules | **49 / 125 proven** · 45 / 45 co-sim PASS, 0 `read_uhdm` divergences · 83 / 83 opt-clean · 1 `differs` formal-only (`bp_me_clint_slice`), 4 over the SAT budget · 57 rows have no `read_slang` reference (27 read_slang cannot elaborate, 30 degenerate at default parameters) · 12 whole-core rows (`bp_processor`, `bp_unicore*`, `bp_core*`, `bp_multicore`, `bp_cacc_tile_node`) exceed the runner's 12 GB Surelog memory cap · `read_slang` diverges on 3 of its own | [black-parrot](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml) |
| **OpenTitan** (upstream) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) @ [`f49474bc`](https://github.com/lowRISC/opentitan/commit/f49474bc89c3ce8a99536329a1e16bf22936da37) | [OTBN](https://github.com/lowRISC/opentitan/tree/master/hw/ip/otbn/rtl) 256-bit bignum accelerator; 32 modules, 122 files | **28 / 32 proven** · 28 / 29 co-sim, 0 divergences (1 adjudicated artefact) · 32 / 32 opt-clean · 4 SAT timeouts (256-bit datapaths) · `read_slang` diverges on 1 of its own (+1 shared artefact) | [opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) |
| **OpenTitan IP library** (upstream) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) @ [`f49474bc`](https://github.com/lowRISC/opentitan/commit/f49474bc89c3ce8a99536329a1e16bf22936da37) | The other 44 of OpenTitan's 45 IP blocks -- `hw/ip`, `hw/ip_templates` and top_earlgrey's generated IP, over the vendored RISC-V debug module and `prim_generic`; 605 modules, 817 RTL files.  Pavona is a hard fork of this tree and is swept separately | **526 / 605 proven** · 545 / 545 co-sim, **0 `read_uhdm` divergences** (6 adjudicated artefacts: enum and FSM-state inputs driven to encodings their `case` never lists) · 591 / 591 opt-clean · 9 `differs` formal-only, 20 over the SAT budget, 48 rows not comparable · `read_slang` diverges on 6 of its own (+6 shared artefacts) | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **Pavona** | [pavona/pavona](https://github.com/pavona/pavona) @ [`61ebeba1`](https://github.com/pavona/pavona/commit/61ebeba10cafca3b0dd43786fa79d26882a5ccf5) | OpenTitan-derived SoC family: hardened Ibex, TL-UL fabric, 27 crypto/peripheral IPs, 2 full chips; 300 module rows + 98 chip instances | **381 / 400 proven** · 380 / 389 co-sim, 0 `read_uhdm` divergences (9 adjudicated artefacts; both full chips build and co-simulate) · 395 / 395 opt-clean · 14 over the SAT budget, 3 miter errors · `read_slang` diverges on 2 of its own (+9 shared artefacts) | [pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) · [per-IP table](pavona_sweep.md) |
| **Ariane CVA6** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | 6-stage 64-bit app-class core (`cv64a6_imafdc_sv39`) + HPDcache, FPnew; 142 modules, plus the full core split into its 138 distinct instantiations (366 instances paired with `read_slang`) | **228 / 280 proven** (142 modules 99, 138 core instantiations 128) · 126 / 135 co-sim, 0 `read_uhdm` divergences (9 adjudicated artefacts) · 273 / 273 opt-clean, 0 undriven on every row · full core lowers with 0 inferred latches · 6 `differs`, all adjudicated non-defects (see [docs/benchmarking.md](benchmarking.md)), 40 over the SAT budget, 3 miter errors | [cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) |
| **Ariane CVA6 flavours** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | The three OTHER configurations chipsalliance/sv-tests builds the core at: `cv64a6_imafdc_sv39_hpdcache` (the HPDcache subsystem instead of the write-through cache), `cv64a6_imafdch_sv39` (the hypervisor extension) and `cv32a6_imac_sv32` (32-bit, Sv32, no FPU).  The same RTL at a different `*_config_pkg.sv`, swept per module like the default; 429 rows over three families | **302 / 429 proven** (hpdcache 99 / 145, H-extension 100 / 142, RV32 101 / 142) · 374 / 402 co-sim, **0 `read_uhdm` divergences** (28 adjudicated artefacts) · 408 / 408 opt-clean · 15 `differs` (the 5 of the base configuration seen three times, all adjudicated non-defects), 93 over the SAT budget, 8 miter errors · `read_slang` diverges on 9 of its own (+28 shared artefacts) | [cva6-flavours](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml) |
| **Caliptra** | [chipsalliance/caliptra-rtl](https://github.com/chipsalliance/caliptra-rtl) | Root-of-trust SoC: VeeR EL2, AXI, mailbox, SHA/HMAC/ECC/Ascon, ML-DSA/ML-KEM; 867 modules, 172 instances | **19 / 22 instances proven** · 21 / 21 co-sim, 0 divergences · 21 / 21 opt-clean, 0 driver conflicts · full-chip co-sim NO_DIVERGENCE over 401 cycles | [caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) |
| **XiangShan** (香山) | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) @ [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | the project's **hand-written** SystemVerilog arithmetic library — SRT dividers, radix-2/4/16 FP divide-sqrt, LZC, CSA, QDS; 21 modules.  **Not the core**, which is Chisel | **19 / 21 proven** · 21 / 21 co-sim, 0 divergences · 21 / 21 opt-clean · 2 SAT timeouts (64-bit divide datapaths) | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **XiangShan core** (香山) | [OpenXiangShan/XiangShan](https://github.com/OpenXiangShan/XiangShan) @ [`e4566c29`](https://github.com/OpenXiangShan/XiangShan/commit/e4566c29e251c60159c6796db60a2569dd7700f2) | Kunminghu out-of-order RV64 core, `CONFIG=DefaultConfig`.  **There is no Verilog to read**: the RTL is the Chisel generator's output (1980 `.sv` + 22 `.v`, 3.2 M lines, 2002 modules, one per file), published as the release asset [`xiangshan-rtl-e4566c29`](https://github.com/alainmarcel/uhdm2rtlil/releases/tag/xiangshan-rtl-e4566c29) and swept module by module in 16 CI shards | whole core elaborates clean (1981 modules / 6.52 M cells, 1 warning) · per-module **1607 / 2002 proven** · 1945 / 1945 co-sim, 0 divergences · 1994 / 1994 opt-clean · 386 over the SAT budget · `read_slang` diverges on 3 | [xiangshan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml) |
| **External IP** (49 families) | see table below | Breadth sweep over third-party (System)Verilog *not* covered above — no vendored copy, each repo fetched at a pinned commit (`test/ext_ip/<family>.json`) | **3084 / 3752 rows proven** (the XiangShan library's 21 rows have their own line) · 3113 / 3219 co-sim · 0 undriven · 84 rows not comparable.  Divergences in this total are all closed or adjudicated (NVDLA's 29 no-oracle rows included: 2 were real defects, 27 diverge identically on the golden `read_verilog` netlist).  **Open leads sit outside it** — 13 families name them in [ext_ip.md](ext_ip.md), largest Rocket Chip 43 rows, Snitch `spatz_vfu` 170, Adams Bridge `abr_ram_regout` 106.  The row total is a FLOOR: BOOM, Gemmini, Rocket Chip and biRISC-V contribute no rows to it (failed shards), aib-protocols reports 198 of its 397 and Cheshire 30 of its 266, so their own lines below carry their real figures | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **chipsalliance/sv-tests** | [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests) @ [`db159ad8`](https://github.com/chipsalliance/sv-tests/commit/db159ad8e9cbbd62036569d240153f753258f640) | The LRM-chapter conformance corpus, not a design: 708 synthesizable tests of its own local suite (`tests/chapter-*`, `generic`, `sanity.sv`). The cores it also defines are swept per core | **read_uhdm 689 / 708** vs read_verilog 365, read_slang 683 · 475 / 527 proven (32 `differs`, 20 no reference) · 527 / 527 opt-clean, 0 conflicts · co-sim on 12 rows, **0 divergences** (1 adjudicated artefact) (`force` / `release`, which has no synthesis semantics on either side, is adjudicated in `test/sv_tests_cosim_analyzed.txt`) | [sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml) · [per-test table](sv_tests_coverage.md) |
| **sv-synth-tests** (the converted sv-tests) | [`test/sv_tests/`](../test/sv_tests) -- the chipsalliance/sv-tests LRM snippets REWRITTEN as synthesizable tests (ports, an observable construct), one directory per upstream test, run by the regression as `sv_tests/<name>` | The conformance corpus made measurable: every converted `dut.sv` gets the columns the other sweeps report -- `read_slang`'s own co-sim vs the RTL, the read_uhdm-vs-read_slang miter (auto-generated over `dut.sv` where no `test_slang_equiv.ys` is committed), the opt-check, the read_uhdm co-sim -- so a `read_slang` failure on an LRM construct is one row of one table | **419 / 434 proven**, 405 / 405 co-sim PASS (10 adjudicated), 0 undriven (nightly 2026-11-08) | [sv-synth-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-synth-tests.yml) |
| **sv-yosys-issues** (the YosysHQ/yosys SystemVerilog-issue corpus) | [`test/yosys_issues/`](../test/yosys_issues) -- the code block(s) of every YosysHQ/yosys issue about SystemVerilog that Surelog parses (906 issues matched the `SystemVerilog` label and keyword searches), one directory per issue and code variant, harvested by [`harvest.py`](../test/yosys_issues/harvest.py); plus the regression's hand-proven `test/yosys_issue_<n>_*` tests | "Is yosys issue #n supported by read_uhdm" as one row of one table: the read_uhdm-vs-read_slang miter, the opt-check, both co-sims -- re-measured nightly, and a new issue is one harvest run away | **164 / 212 proven** (24 have no `read_slang` reference, 0 differ), 136 / 137 co-sim PASS (11 adjudicated; the one divergence is issue 5837, a never-assigned 2-state variable whose expected value awaits a decision), 0 undriven (nightly 2026-11-09) | [sv-yosys-issues](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-yosys-issues.yml) |
| **sv-elab-issues** (the povik/sv-elab issue corpus) | [`test/sv_elab_issues/`](../test/sv_elab_issues) -- the code block(s) of every issue of [povik/sv-elab](https://github.com/povik/sv-elab/issues), the elaborator behind yosys's `read_slang`, open and closed (188 issues), plus sv-elab's per-issue regression tests and its `regress.sv` split into one row per regression; harvested by [`harvest.py`](../test/sv_elab_issues/harvest.py), whose [ledger](../test/sv_elab_issues/README.md) maps every issue to its test or the reason it has none | Each issue is a construct a real design asked of a SystemVerilog frontend: "does read_uhdm handle sv-elab issue #n" as one row, with the read_uhdm-vs-read_slang miter, the opt-check and both co-sims, re-measured nightly | **85 / 138 proven** (31 have no `read_slang` reference -- the vendored read_slang still rejects or aborts on them; 16 have no logic or no miter; 4 adjudicated known-diffs; 2 SAT timeouts; 0 differ), 52 / 52 co-sim PASS (3 adjudicated; 166 and 167 are rejected by design -- procedural `assign`/`force`), 0 undriven (local sweep 2026-11-13; 91 of the 188 issues carry code that becomes a test; every issue triaged as a read_uhdm defect is fixed, including tagged unions, #168) | [sv-elab-issues](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-elab-issues.yml) |

**Benchmarking against the reference frontend.**  Every row also co-simulates
the `read_slang` netlist, so the reference is measured by the same yardstick:
over the latest complete nightly of each of the 21 sweeps (2026-11-09, counted
by `test/sweep_table.py`), **11707 rows, 8977 formally proven, `read_uhdm` 9688
co-sim passes, `read_slang` 9506**, 0 undriven anywhere.  (The 2026-11-04
paragraph's 12322 was an older counting method; the same script gives 11382
for those reports.)

NVDLA's own figure is **776 / 914 proven**.  Its 41 slang-CLEAN co-sim
divergences are closed, and so are its 29 rows with no `read_slang` oracle:
**2 were real defects** (`RUBIK_dr2drc`, `PDP_rdma`, both co-sim PASS now) and
27 are artefacts that diverge from the RTL by exactly the same count as the
golden `read_verilog` netlist.
OpenPiton and OpenC910 have no open reader lead: their rows that read_slang
refuses are adjudicated against the golden `read_verilog` netlist, which
diverges identically on each (an `assign #1` delay on OpenC910's `axi2ahb`, a
ternary asynchronous reset on three OpenPiton flop primitives — neither
expressible by any yosys frontend).

**What the aggregate contains, as of 2026-11-04.**  The four families that
contributed ZERO rows to the 2026-10-28 aggregate -- BOOM, Gemmini, Rocket Chip
and biRISC-V, whose external-IP shards used to fail and publish empty reports --
now report from CI: **BOOM 422, Gemmini 384, Rocket Chip 235, biRISC-V 44 =
1085 rows**, which is exactly the shortfall
[benchmarking.md](benchmarking.md) predicted.  The partial families are complete
too: **Cheshire reports its full 266** (it reported 30, sweeping only the
vendored `UsbOhciAxi4` modules -- that open harness question is closed),
**aib-protocols 397** (was 198) and **OpenPiton 852** (was 756).  So no entry
below needs a **(local)** figure on these grounds any more; a row still marked
**(local)** is one with no nightly at all.  The
per-core table, the provenance of
every number, the reference frontend's own record and the nightly 4-frontend
matrix (`uhdm` / `sv2v` / `slang` / `verilog`, 1847 tests: `uhdm` reads 1815,
669 of them designs `read_verilog` cannot read at all) are in
**[docs/benchmarking.md](benchmarking.md)**.

**Pavona vs upstream OpenTitan** are swept separately on purpose: pavona is a
hard *fork* whose RTL has diverged — of the 120 files the two trees share,
only **66 are byte-identical** (`kmac_app.sv` differs by 1531 lines) — so a
pavona verdict is not an upstream verdict.  OTBN does not exist in pavona at
all, so every OpenTitan row is new coverage.

## External IP families

Scores are over **comparable** modules — a module whose own default parameters
do not give a legal elaboration, or that `read_slang` cannot read, has no
reference to be judged against and is excluded rather than counted as a
failure.  `undriven` likewise counts comparable rows only.

Every figure is the family's CURRENT state, from its latest nightly — except
where it is marked **(local)**, which is a local sweep whose first nightly has
not landed yet.

| Family | Upstream repo | Commit | Proven | Not comparable | Undriven |
|---|---|---|---|---|---|
| PULP AXI | [pulp-platform/axi](https://github.com/pulp-platform/axi) | [`70b8e54f`](https://github.com/pulp-platform/axi/commit/70b8e54fd460) | **92 / 93** | 15 of 108 | 0 (`axi_lfsr` and `axi_lite_lfsr` carry 64 bits each the source never assigns — an unconnected `data_i` on the read-side LFSR — reported as such, not as dropped drivers) |
| PULP common_cells | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) | [`121182ea`](https://github.com/pulp-platform/common_cells/commit/121182eaa0fa) | **120 / 120** | 0 of 120 | 0 |
| OpenHW CVE2 | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | [`d079e8c8`](https://github.com/openhwgroup/cve2/commit/d079e8c8e6a0) | **17 / 21** | 2 of 23 | 0 |
| OpenHW CV32E40P | [openhwfoundation/cv32e40p](https://github.com/openhwfoundation/cv32e40p) | [`6033d2b1`](https://github.com/openhwfoundation/cv32e40p/commit/6033d2b1be32) | **21 / 25** | 1 of 26 | 0 |
| OpenHW CVFPU | [openhwfoundation/cvfpu](https://github.com/openhwfoundation/cvfpu) | [`77811635`](https://github.com/openhwfoundation/cvfpu/commit/77811635cb7e8649f1d9484733ee6a0bdb44a0e6) | **12 / 19** | 1 of 20 | 0 (`control_mvp` and its parents: 4 bits the source never assigns) |
| OpenHW CORE-V Wally | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | [`bc7012a9`](https://github.com/openhwgroup/cvw/commit/bc7012a92273) | **174 / 193** | 27 of 220 | 0 |
| hdl-util HDMI | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | [`83b1c954`](https://github.com/hdl-util/hdmi/commit/83b1c9543a91) | **8 / 9** | 2 of 11 | 0 |
| verilog-ethernet | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | [`77320a94`](https://github.com/alexforencich/verilog-ethernet/commit/77320a9471d1) | **103 / 118** | 11 of 129 | 0 (`xgmii_interleave` bit 72 is never assigned in the source) |
| verilog-pcie | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) | [`25156a9a`](https://github.com/alexforencich/verilog-pcie/commit/25156a9a162c) | **72 / 88** | 5 of 93 | 0 |
| XiangShan XS-Verilog-Library | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) | [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | **19 / 21** | 0 of 21 | 0 |
| Caliptra subsystem | [chipsalliance/caliptra-ss](https://github.com/chipsalliance/caliptra-ss) | [`dfa6c631`](https://github.com/chipsalliance/caliptra-ss/commit/dfa6c631dbfc) | **241 / 257** | 16 of 273 | 0 |
| chipsalliance Adams Bridge | [chipsalliance/adams-bridge](https://github.com/chipsalliance/adams-bridge) | [`c4a921cf`](https://github.com/chipsalliance/adams-bridge/commit/c4a921cf) | **112 / 117** | 0 of 117 | 0 |
| chipsalliance AIB protocols | [chipsalliance/aib-protocols](https://github.com/chipsalliance/aib-protocols) | [`9e308bfb`](https://github.com/chipsalliance/aib-protocols/commit/9e308bfb) | **379 / 397** (local) | 0 of 397 | 0 |
| chipsalliance AIB PHY | [chipsalliance/aib-phy-hardware](https://github.com/chipsalliance/aib-phy-hardware) | [`a0295cd2`](https://github.com/chipsalliance/aib-phy-hardware/commit/a0295cd2) | **72 / 72** | 3 of 75 | 0 |
| chipsalliance VeeRwolf | [chipsalliance/VeeRwolf](https://github.com/chipsalliance/VeeRwolf) | [`9a919805`](https://github.com/chipsalliance/VeeRwolf/commit/9a919805) | **22 / 24** | 2 of 26 | 0 |
| SERV | [olofk/serv](https://github.com/olofk/serv) | [`f200eb2e`](https://github.com/olofk/serv/commit/f200eb2e) | **27 / 27** | 2 of 29 | 0 |
| LiteX | [enjoy-digital/litex](https://github.com/enjoy-digital/litex) | [`7457e137`](https://github.com/enjoy-digital/litex/commit/7457e137) | **3 / 3** | 0 of 3 | 0 |
| VexRiscv | [SpinalHDL/VexRiscv](https://github.com/SpinalHDL/VexRiscv) | [`baf7dc82`](https://github.com/SpinalHDL/VexRiscv/commit/baf7dc82) | **3 / 3** | 0 of 3 | 0 |
| PULP APB | [pulp-platform/apb](https://github.com/pulp-platform/apb) | [`4821618d`](https://github.com/pulp-platform/apb/commit/4821618d) | **8 / 8** (local) | 0 of 8 | 0 |
| lowRISC Sonata | [lowRISC/sonata-system](https://github.com/lowRISC/sonata-system) | [`21e84afb`](https://github.com/lowRISC/sonata-system/commit/21e84afb) | 37 / 37 read (local) | 0 of 37 | 0 |
| PULP tech_cells_generic | [pulp-platform/tech_cells_generic](https://github.com/pulp-platform/tech_cells_generic) | [`55cb5451`](https://github.com/pulp-platform/tech_cells_generic/commit/55cb5451) | **44 / 50** (local) | 3 of 53 | 0 |
| PULP register_interface | [pulp-platform/register_interface](https://github.com/pulp-platform/register_interface) | [`d6e1d4cd`](https://github.com/pulp-platform/register_interface/commit/d6e1d4cd) | **11 / 11** (local) | 8 of 19 | 0 |
| CV32E40S | [openhwfoundation/cv32e40s](https://github.com/openhwfoundation/cv32e40s) | [`9d9cae78`](https://github.com/openhwfoundation/cv32e40s/commit/9d9cae78) | **36 / 42** (local) | 6 of 48 | 0 |
| CV32E41P | [openhwfoundation/cv32e41p](https://github.com/openhwfoundation/cv32e41p) | [`b5d1ba14`](https://github.com/openhwfoundation/cv32e41p/commit/b5d1ba14) | **17 / 21** (local sweep 2026-11-06; first nightly pending) | 2 of 23 | 0 |
| CV32E40X | [openhwfoundation/cv32e40x](https://github.com/openhwfoundation/cv32e40x) | [`d952cd63`](https://github.com/openhwfoundation/cv32e40x/commit/d952cd63) | **30 / 35** (local) | 7 of 42 | 0 |
| NaxRiscv | [SpinalHDL/NaxRiscv](https://github.com/SpinalHDL/NaxRiscv) | [`9f452d50`](https://github.com/SpinalHDL/NaxRiscv/commit/9f452d50) | **17 / 24** (local) | 0 of 24 | 0 |
| Rocket Chip | [chipsalliance/rocket-chip](https://github.com/chipsalliance/rocket-chip) | [`ece7b9ad`](https://github.com/chipsalliance/rocket-chip/commit/ece7b9ad) | **176 / 235** (local) | 0 of 235 | 0 |
| biRISC-V | [ultraembedded/biriscv](https://github.com/ultraembedded/biriscv) | [`6af9c4be`](https://github.com/ultraembedded/biriscv/commit/6af9c4be) | **28 / 44** | 7 of 44 | 0 |
| ZipCPU | [ZipCPU/zipcpu](https://github.com/ZipCPU/zipcpu) | [`42606d2d`](https://github.com/ZipCPU/zipcpu/commit/42606d2d) | **46 / 50** | 1 of 51 | 0 |
| Hazard3 | [Wren6991/Hazard3](https://github.com/Wren6991/Hazard3) | [`8af99293`](https://github.com/Wren6991/Hazard3/commit/8af99293) | **21 / 22** | 3 of 25 | 0 |
| NVDLA | [nvdla/hw](https://github.com/nvdla/hw) | [`8e06b1b9`](https://github.com/nvdla/hw/commit/8e06b1b9) | **776 / 835** | 79 of 914 | 0 — 70 `read_uhdm` co-sim divergences at that nightly, 41 slang-clean; **38 are since fixed**, 3 remain |
| OpenE906 | [XUANTIE-RV/opene906](https://github.com/XUANTIE-RV/opene906) | [`c5b87895`](https://github.com/XUANTIE-RV/opene906/commit/c5b87895) | **203 / 255** (local) | 0 of 255 | 0 |
| OpenC910 | [XUANTIE-RV/openc910](https://github.com/XUANTIE-RV/openc910) | [`b91c9093`](https://github.com/XUANTIE-RV/openc910/commit/b91c9093) | **359 / 477** | 5 of 482 | 0 |
| BOOM | [riscv-boom/riscv-boom](https://github.com/riscv-boom/riscv-boom) | [`ba03175e`](https://github.com/riscv-boom/riscv-boom/commit/ba03175e) | **326 / 422** (local) | 0 of 422 | 0 |
| Gemmini | [ucb-bar/gemmini](https://github.com/ucb-bar/gemmini) | [`8c3f9923`](https://github.com/ucb-bar/gemmini/commit/8c3f9923) | **340 / 384** (local) | 0 of 384 | 0 |
| OpenPiton | [PrincetonUniversity/openpiton](https://github.com/PrincetonUniversity/openpiton) | [`1c6bfd2d`](https://github.com/PrincetonUniversity/openpiton/commit/1c6bfd2d) | **694 / 838** (local) | 14 of 852 | 0 |

## Generated IP: the XiangShan core

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

AXI's not-comparable rows: PULP declares its struct ports through type
parameters (`parameter type axi_resp_t = logic`), so a module swept standalone
with its defaults performs a member access on a 1-bit `logic` — not legal
SystemVerilog, and nothing to compare against.  The manifest's `bind` section
gives those modules concrete types and values instead; the rest are recorded
with the slang diagnostic that identifies them.
