# External IP sweeps (`test/ext_ip/`)

Manifest-driven per-module sweeps of external SystemVerilog / Verilog
repositories, on top of the same three checks the core-IP rows use: formal
equivalence read_uhdm vs `read_slang` (SAT miter from reset), a structural
opt-check (undriven nets after `read_uhdm`), and Verilator co-simulation of
both netlists against the behavioural RTL (`test/netlist_cosim.py`).  Nothing
is vendored: each family's repositories are shallow-cloned at a pinned commit
(`$EXT_IP_ROOT`, default `~/ext` on a developer machine, `test/ext_ip/repos/`
in CI).

Run one family locally:

```bash
cd test
python3 core_sweep.py common_cells --jobs 2 --cycles 300   # any family below
python3 ext_ip/ext_flow.py hdmi --survey                   # elaborate only (first pass)
python3 ext_ip/ext_flow.py axi --list                      # module list
```

The nightly [Sweep external IP](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml)
workflow runs every family below as one sweep job and publishes the per-module
table to the run's step summary.

## Families

| Family | Repository | Modules | First survey (elaborate with read_uhdm) | Notes |
|--------|------------|--------:|------------------------------------------|-------|
| `common_cells` | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) (+ tech_cells_generic) | 126 | 121 / 126 read; **110 / 126 formally proven, 109 co-sim PASS** in the first full run | 2 reader crashes (`cc_cb_filter`, `cc_hash_block`: constant-function permutation tables), `cc_sub_per_hash` / `cc_id_queue` / `cc_mem_to_banks*` differ, 4 `*_clearable` CDC modules read_slang-only failures, 1 recursive instantiation |
| `axi` | [pulp-platform/axi](https://github.com/pulp-platform/axi) | 108 | 87 / 108 read | reader assertion on the `axi_burst_*` family; most `*_intf` wrappers fail in read_slang (interface ports) |
| `cve2` | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | 23 | 23 / 23 read | OpenHW CVE2 (2-stage RV32 core, Ibex lineage) |
| `cvw` | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | 234 | 211 / 234 read | CORE-V Wally; most modules take `parameter cvw_t P` with no default, so read_slang refuses them standalone — the SoC top needs a config-package wrapper |
| `verilog-ethernet` | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | 129 | 125 / 129 read | Verilog-2001 corpus (+ its axis library) |
| `verilog-pcie` | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) (+ verilog-axis) | 93 | 80 / 93 read | `dma_psdpram*` "missing edge-sensitive event", several DMA / PTile modules fail to read |
| `hdmi` | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | 10 | 9 / 10 read | top `hdmi` out-of-range bit-select on read; `packet_picker` 62k undriven (partially assigned `headers` table, read_slang fails too) |
| `opentitan-ip` | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) (hw/ip, hw/ip_templates, top_earlgrey ip_autogen; + the vendored pulp_riscv_dbg / pulp_common_cells for the closure) | 605 | 527 / 605 proven, 545 / 551 co-sim, 0 read_uhdm divergences (6 adjudicated artefacts) | upstream OpenTitan's IP library, 44 of its 45 blocks (OTBN is `test/opentitan_equiv/`); vendor technology libraries (`prim_asap7`, `prim_xilinx*`) and one Xilinx-only JTAG tap excluded as SOURCES, chip tops excluded as rows; first-shard leads (`prim_gf_mult` 300 div, `rram_phy_rd_buf_dep` 73 div) fixed in #1270 / #1275; `i3c_target_fsm` differs has no co-sim oracle |
| `adams-bridge` | [chipsalliance/adams-bridge](https://github.com/chipsalliance/adams-bridge) @ c4a921cf (the commit caliptra-rtl vendors) | 117 | **112 / 117 proven**, 115 / 116 co-sim PASS, **1 `read_uhdm` divergence** (`abr_piso_multi`, 33 cycles, read_slang clean -- open), 1 shared | the ML-DSA (Dilithium) accelerator's own modules: NTT, samplers, encoders / decoders, SHA3, the control block and `abr_top`; the caliptra sweep measures only its instances. UVMF / tb / sim trees excluded as sources; `bytewrite_tdp_ram_rf` (inside `ifdef RV_FPGA_OPTIMIZE`) and `abr_prim_lc_sync` (needs the absent lc_ctrl_state_pkg) excluded as rows; the two SRAM models are always_srcs because `abr_mem_top` instantiates them through macros in an included .svh. Leads: abr_ram_regout 106 div, abr_1r1w_be_ram 98, pkdecode 84 (all read_slang clean, all formal `differs` too) and abr_piso_multi 31 div (read_slang clean; its miter holds only to the sweep's seq 3, so the row counts as proven) |
| `aib-protocols` | [chipsalliance/aib-protocols](https://github.com/chipsalliance/aib-protocols) @ 9e308bfb | 397 | **379 / 397 proven** (first local sweep, 2026-10-24; the nightly refreshes this), 386 / 386 co-sim PASS, 0 `read_uhdm` divergences | the AIB die-to-die protocol layers: logic link, the AXI4-MM / AXI4-Stream / duplex generated configurations, LPIF at every width, SPI-AIB, channel alignment; dv / sims / backup / llink script+fpga trees excluded as sources (premade_examples duplicates 49 modules), nine example tops excluded as rows (they instantiate the PHY's DV EMIB model or generated configurations no file defines). Leads: levelsync_sr read-fail = the two-async-control flop (fix in hand, next reader PR); axi_st_patchkr_top / _h2f_top / _f2h_top read-fail "Multiple edge sensitive events found" (an async-reset arm proc cannot recognise, behind two out-of-range part-selects of a 256-bit bus at [511:0]); axi_st_patgen_dual_top / axi_st_h2h_patgen_top `error` = a $mux output driven twice in our netlist (miter refuses it; co-sim PASS). Not reader findings: the 5 aximm_*gpiophy* / h2h wrapper tops connect `.init_ar_credit` to a port their generated axi_mm_master_top does not have (read_slang stops, Surelog tolerates it); lpif / lpif_ctl trip read_slang on `default: MEM_CACHE_STREAM_ID: protid = ...` (lpif_ctl.sv:914, a labelled statement after `default:`) |
| `aib-phy-hardware` | [chipsalliance/aib-phy-hardware](https://github.com/chipsalliance/aib-phy-hardware) @ a0295cd2 (v2.0/rev1.1) | 75 | **72 / 72 comparable proven** of 75 rows, 72 / 72 co-sim PASS, 0 `read_uhdm` divergences | the AIB 2.0 PHY's digital RTL: adapter tx/rx channels, FIFOs, DBI, BERT, shift-register config, Avalon interface, CDR / phase-adjust / offset-calibration FSMs, redundancy, aib_phy_top; the ana_models/ behavioural IO / DLL / PVT-monitor models are closure-only sources (`real`, `#` delays; read_slang refuses them). Leads: aib_phy_top, aib_channel_n and aibio_ana_top read-fail on the two-async-control flop of the analog DLL model they instantiate (`always @(posedge i_clkp or negedge i_dll_en or posedge i_reset)` in aibio_dll_top) -- the same defect as aib-protocols' levelsync_sr, fix in hand |
| `veerwolf` | [chipsalliance/VeeRwolf](https://github.com/chipsalliance/VeeRwolf) @ 9a919805 (v0.7.5) | 26 | **22 / 24 comparable proven** of 26 rows, 23 / 23 co-sim PASS, 0 `read_uhdm` divergences (1 shared artefact, `veerwolf_syscon`) | the reference SoC around VeeR EL2 -- AXI interconnect, AXI-to-Wishbone bridge, Wishbone interconnect, syscon, memory wrapper, UART 16550, SPI -- closed through its own FuseSoC build (`test/ext_ip/veerwolf_setup.sh` generates the interconnects and the EL2 configuration and fetches the fusesoc-cores libraries); rows are VeeRwolf's modules, the generated interconnects and the Wishbone peripherals, the EL2 core / PULP axi / common_cells closure-only. Leads: simple_spi `error` -- our netlist carries a `$memory ... rdmux` cell the miter refuses, beside 144 co-sim divergences (slang clean); axi_intercon 279 div (slang clean; the generated AXI interconnect); uart_rfifo formal `differs` with a co-sim PASS |
| `serv` | [olofk/serv](https://github.com/olofk/serv) @ f200eb2e | 29 | **27 / 27 comparable proven** (first local sweep, 2026-10-25; the nightly refreshes this), 27 co-sim PASS (the SoC top with 0 active cycles among them), 0 `read_uhdm` divergences; `servant` (the SoC top) has no read_slang reference (its memfile parameter names a hex file relative to the build directory), `serv_rf_ram` is degenerate at its default width | The bit-serial RISC-V core (rtl/), the servant reference SoC and peripherals, servile / serving wrappers; the board tops (servant_<board>, *_clock_gen, PLL wrappers) instantiate vendor primitives no file defines and are excluded |
| `litex` | [enjoy-digital/litex](https://github.com/enjoy-digital/litex) @ 7457e137 (release 2026.08) | 4 | **3 / 4 proven** (first local sweep, 2026-10-25; the nightly refreshes this), 4 / 4 co-sim PASS, 0 `read_uhdm` divergences; `InstructionCache` (the VexRiscv I-cache) is `differs` formal-only with a 299-active-cycle co-sim PASS -- a lead to adjudicate | The litex_sim SoC (`sim`: CPU wrapper, Wishbone / CSR interconnect, UART, timer, SRAM / ROM) generated by Migen with `--cpu-type=vexriscv --no-compile`, plus the VexRiscv core LiteX ships (pythondata-cpu-vexriscv) |
| `vexriscv` | [SpinalHDL/VexRiscv](https://github.com/SpinalHDL/VexRiscv) @ baf7dc82 | 3 | **3 / 3 proven** (first local sweep, 2026-10-25; the nightly refreshes this), 3 / 3 co-sim PASS, 0 `read_uhdm` divergences, 0 undriven | The GenFull configuration (MMU, caches, debug, mul/div, CSRs) emitted by SpinalHDL as one Verilog file: the core, `InstructionCache` and `DataCache`; generated by `sbt runMain vexriscv.demo.GenFull` through `test/ext_ip/vexriscv_setup.sh` |
| `rocket-chip` | [chipsalliance/rocket-chip](https://github.com/chipsalliance/rocket-chip) @ ece7b9ad | 235 | **176 / 235 proven** (first local sweep, 2026-10-25; the nightly refreshes this), 189 / 235 co-sim PASS, 43 rows with `read_uhdm` co-sim divergences (slang clean; the DivSqrt*_small, Repeater_TLBundleA_*, TLInterconnectCoupler_* and AXI4 fragmenter / deinterleaver families -- one firtool-pattern lead), 18 SAT-budget rows, 0 undriven | The DefaultConfig Rocket core with FPU, L1 caches, PTW, TileLink fabric, debug module, PLIC / CLINT, emitted by firtool as one SystemVerilog file per module through `test/ext_ip/rocket_setup.sh` (mill + firtool + dtc); the TestHarness, its simulation models and the TLMonitor checkers are excluded, as is the 2 Gbit TestHarness backing memory (a reader lead: RTLIL::WIDTH_LIMIT) |
| `biriscv` | [ultraembedded/biriscv](https://github.com/ultraembedded/biriscv) @ be4b5d3b | 44 | **28 / 40 proven** (first local sweep, 2026-10-26; the nightly refreshes this), every co-simulated row PASS, 0 undriven, 6 SAT-budget rows, 4 `differs` leads with clean co-simulations (`biriscv_exec`, `_frontend`, `_npc`, `dcache_core_tag_ram`) | The dual-issue RV32IM core (fetch, the branch predictor `biriscv_npc`, decode, both execute units, the multiplier / divider, the register file, the CSRs), its instruction and data caches with their RAMs, the TCM, and the `riscv_top` / `riscv_tcm_top` SoC tops |

"read" = Surelog elaborates and `read_uhdm` + `hierarchy -check` succeed; the
nightly table adds the miter verdict, the opt-check and the co-sim result per
module.  The first survey findings above are **tracked, not yet fixed** — the
point of the sweep is to keep the counts moving in the open.

## Not duplicated here

- **Ibex** — `test/ibex/` (own sweep) and the Pavona hardened variant.
- **CVA6 and its HPDcache** — `test/cva6_equiv/` (own sweep; the HPDcache
  modules are part of it).
- **OpenTitan IP blocks** — UPSTREAM lowRISC OpenTitan's IP library is the
  `opentitan-ip` family in the table above (605 modules, 44 of its 45 blocks;
  the 45th, OTBN, is `test/opentitan_equiv/`'s own sweep).  The Pavona families
  in [pavona_sweep.md](pavona_sweep.md) are the OpenTitan-DERIVED IPs of a hard
  fork whose RTL has diverged, so the two are not duplicates.  The Earlgrey chip
  top is not a row yet: `test/opentitan_equiv/scripts/fusesoc_closure.py`
  resolves it (635 files, 0 unresolved cores) and read_uhdm reads it clean, but
  that read peaks at 11.9 GB and wants its own sharded workflow.
- **snitch_cluster / cheshire** (PULP) need their Bender dependency sets
  fetched before a manifest makes sense; **XiangShan** is generated SystemVerilog
  and is deferred.

## Manifest

`test/ext_ip/<family>.json`:

```json
{"repos": [{"url": "...", "commit": "abc1234", "dir": "name", "submodules": false}],
 "roots": ["name/src/*.sv"], "incdirs": ["name/include"], "defines": ["SYNTHESIS"],
 "modules": "auto", "exclude": ["_tb$"], "only_prefix": "axi_",
 "seq": 4, "timeout": 300, "want": "proven"}
```

`ext_flow.py` computes each module's dependency closure by an identifier scan
over the roots (packages first), runs Surelog with `-top <module>`, then the
three checks, and writes `work/<family>/rows.json` in `core_sweep.py`'s row
schema; `core_sweep.py <family>` fetches the repositories, runs it (sharded
runs take every N-th module) and renders the table.
