# To do: cores and IP to bring under the sweeps

What is swept today is in [supported_ip.md](supported_ip.md) (18 nightly
workflows, 5957 rows).  This page is the queue of what is **not** yet: named in
earlier planning, or popular open-source RTL we have no row for.  Each entry
says what it is, what blocks it, and how it would be swept.  The rule from the
external-IP campaign still holds: land the manifest and read the first nightly
before fixing anything it finds.

## Named in earlier planning, not started

| Candidate | Repo | What it is | Status / what it needs |
|---|---|---|---|
| **OpenTitan `top_earlgrey`** | lowRISC/opentitan | The full chip: the 44 IP blocks we sweep per module, wired up | Closure solved 2026-10-21 by walking the CAPI=2 `.core` graph directly (635 files, 0 unresolved, 0 syntax errors with `-DSYNTHESIS`; one Surelog error, `alert_handler` `AsyncOn`); `read_uhdm` reads it clean at **11.9 GB**, 13.5 GB with flatten+check, so a 16 GB nightly runner cannot hold it: needs its own sharded workflow and a flat shim for its interface-free top before it gets a formal and a co-sim column.  10 `Reference to unknown signal` warnings (type names, loop variables, parameters) are untriaged. |
| **VeeR EH2** | chipsalliance/Cores-VeeR-EH2 | The dual-threaded successor of VeeR EH1 (swept) and sibling of EL2 (swept); SystemVerilog, 283★ | **Swept** (`test/ext_ip/veer-eh2.json`, `sweep-veer-eh2.yml`, nightly 04:03 UTC) at 32bdfe24. First local sweep 2026-10-23: 73 / 100 proven, 100 / 100 elaborate; co-sim 86 / 96 PASS, 8 read_uhdm divergences with read_slang clean + 1 with no read_slang reference (`eh2_veer_wrapper`) + 1 shared; 9 over the SAT budget, 14 `differs`, 4 no reference; 0 undriven on every row. Reader leads from it, one per PR: eh2_lsu_lsc_ctl 218 div, eh2_ifu_mem_ctl 155, eh2_lsu_addrcheck 116, eh2_lsu 101, eh2_dma_ctrl 48, eh2_exu 45, eh2_exu_alu_ctl 25, eh2_ifu 7 (all read_slang clean); eh2_veer_wrapper 44 div with no read_slang reference (`$assertoff` unsupported there); eh2_veer shared divergence (uhdm 71 / slang 2); formal-only `differs` beside a co-sim PASS on ahb_to_axi4 / axi4_to_ahb (the reader turns the SVA `property ahb_error_protocol` NAME into an undriven signal reference -- EH1's bridge, without the property, is equivalent), eh2_ifu_bp_ctl, eh2_ram, eh2_mem. |
| **i3c-core** | chipsalliance/i3c-core | MIPI I3C target/controller core | **Already measured twice**: the caliptra-ss family sweeps its vendored copy (`caliptra-ss/third_party/i3c-core`, commit 067bfe14 of 2026-08-03) and the OpenTitan library its own (`i3c_*` rows, where `i3c_target_fsm` is `differs` with no co-sim oracle and `i3c_phy` read-fails with `$mux Y already driven`).  A standalone row set at the upstream head (e33a8bbc, 2026-09-15) only adds freshness; low priority. |
| **VeeRwolf** | chipsalliance/VeeRwolf | FuseSoC SoC around VeeR EH1 / EL2, Verilog, 343★ | The SoC glue is 10 files (`rtl/veerwolf_core.v`, `axi2wb`, `wb_mem_wrapper`, syscon, board tops), but `veerwolf.core` depends on FuseSoC library cores not in the repo (uart16550, simple_spi, wb_intercon, pulp axi, the litedram generator): a fusesoc library fetch or vendoring of those four is the work. |
| **AIB PHY / protocols** | chipsalliance/aib-phy-hardware, aib-protocols | Advanced Interface Bus die-to-die PHY and protocol layers, Verilog | Plain Verilog, small; a manifest per repo. |
| **adams-bridge** | chipsalliance/adams-bridge | Post-quantum (ML-DSA) IP, SystemVerilog, 221 RTL files | **Swept** (`test/ext_ip/adams-bridge.json`, a `sweep-ext.yml` matrix entry, 2 shards) at c4a921cf, the commit caliptra-rtl vendors: NTT, samplers, encoders / decoders, SHA3, the control block, `abr_top`. First local sweep 2026-10-23: 110 / 117 proven, 117 / 117 elaborate, 0 no reference; co-sim 112 / 117 PASS, 4 read_uhdm divergences (read_slang clean) + 1 shared (abr_mem_top: uhdm 129 / slang 14, over the SAT memory cap); 4 over the SAT budget, 3 `differs`; 0 undriven on every row. Reader leads from it, one per PR: abr_ram_regout 106 div, abr_1r1w_be_ram 98, pkdecode 84 (all read_slang clean, all formal `differs` too) and abr_piso_multi 31 div (read_slang clean; its miter holds only to the sweep's seq 3, so the row counts as proven). |
| **cv32e40x, cv32e40s, cv32e41p, core-v-mcu** | openhwfoundation | The OpenHW cores not yet swept (cv32e40p, cvfpu, cve2, cva6, Wally are) | Same manifest shape as `cv32e40p.json`; cv32e40x carries the core-v-xif interface on its top only, so its top needs the interface flat shim. |
| **Snitch cluster, Cheshire** | pulp-platform/snitch_cluster, pulp-platform/cheshire | PULP's many-core cluster and its Linux-capable host SoC | Cloned under `~/ext` in September, never started: their source closure is defined by **Bender** dependency files, so `ext_flow.py` needs a Bender-resolved file list (or a checked-in `Bender.lock` walk) before any module can be a row. |
| **register_interface, apb, tech_cells_generic** | pulp-platform | Small PULP libraries we already clone as closure roots for axi / common_cells | One manifest each; expected to be mostly clean and quick. |

## Popular open-source RTL with no row yet

Grouped by what the sweep would reuse.  Generated RTL (Chisel, SpinalHDL,
Migen) goes through the XiangShan-core flow (one `.sv` tree, modules swept per
module, `--single-unit` for read_slang); hand-written Verilog is the class
most likely to expose new reader cases.

| Candidate | Repo | Notes |
|---|---|---|
| **OpenC910 / OpenE906** | XUANTIE-RV/openc910, opene906 | T-Head's 64-bit and 32-bit cores, hand-written Verilog; their FPU pieces are already vendored under `cvfpu` and read.  Large (C910 ~ 1.7k files). |
| **Rocket Chip / BOOM** | chipsalliance/rocket-chip, riscv-boom/riscv-boom | Chisel generators (3.9k★): emit the SystemVerilog with firtool, then the XiangShan-core flow.  Needs a generator run in the harness or a vendored emitted tree with its provenance note, as XiangShan has. |
| **VexRiscv / NaxRiscv** | SpinalHDL/VexRiscv, SpinalHDL/NaxRiscv | SpinalHDL output, one Verilog file per configuration; small, quick rows. |
| **Hazard3** | Wren6991/Hazard3 | RV32IMAC core (the RP2350 core), hand-written SystemVerilog, small. |
| **SERV** | olofk/serv | The bit-serial RISC-V core, Verilog, FuseSoC; tiny -- a good first row for a FuseSoC closure. |
| **biRISC-V, uriscv, ultraembedded cores** | ultraembedded/biriscv, ultraembedded/core_* | Hand-written Verilog cores and I/O blocks (USB, SD, UART); each repo one manifest. |
| **SweRVolf / Caravel SweRV** | chipsalliance/VeeRwolf, caravel-swerv-el2 | SoC harnesses around cores we prove; see above. |
| **OpenPiton** | PrincetonUniversity/openpiton | Manycore framework hosting Ariane (our CVA6); the uncore (NoC, L1.5 / L2 caches) is hand-written Verilog with many `ifdef`s -- the config closure is the work. |
| **PULPissimo** | pulp-platform/pulpissimo | PULP's single-core microcontroller platform; Bender closure as for Snitch. |
| **LiteX** | enjoy-digital/litex | Migen-generated SoCs: emit one Verilog file per configuration, then sweep; the peripheral library (LiteDRAM, LiteEth) comes with it. |
| **ZipCPU + wishbone peripherals** | ZipCPU/zipcpu, wbuart32, sdspi, ... | Hand-written Verilog with formal properties already in the source (`ifdef FORMAL`); several small repos, one manifest each. |
| **NVDLA** | nvdla/hw | The largest open accelerator (7k★), Verilog generated from a template language; the emitted `outdir/*/vmod` tree is what to sweep. |
| **Gemmini, VTA** | ucb-bar/gemmini, apache/tvm-vta | Chisel accelerators; emitted SystemVerilog through the XiangShan-core flow. |
| **Ibex-based SoCs, Sonata** | lowRISC/sonata-system | CHERIoT-Ibex SoC (the OpenTitan library's `cheriot_*` rows are its building blocks); FuseSoC closure. |
| **NEORV32** | stnolting/neorv32 | VHDL only -- out of scope for a SystemVerilog frontend; listed so it is not asked about again. |

## Already covered -- do not duplicate

Ibex (`test/ibex` and inside Pavona), CVA6 with HPDcache and its three other
configurations, all 45 OpenTitan IP blocks, Pavona, Caliptra and caliptra-ss,
VeeR EH1 and EL2, SCR1, rp32, fx68k, RgGen, TNoC, RSD, BlackParrot, the
XiangShan core and its arithmetic library, PULP axi and common_cells, OpenHW
cve2 / cv32e40p / cvfpu / Wally, verilog-ethernet, verilog-pcie, hdl-util HDMI,
and the chipsalliance/sv-tests conformance corpus.
