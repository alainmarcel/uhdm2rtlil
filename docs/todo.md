# Coverage: what is done, and what is left

**Swept means supported.**  A design in the DONE table has a landed manifest,
runs in a nightly workflow, and its CURRENT numbers live in
[supported_ip.md](supported_ip.md) and [ext_ip.md](ext_ip.md).

This page tracks **coverage only** — which designs are under the sweeps at all.
It is not a defect tracker: each family's open leads and SAT-budget rows are
recorded beside that family's numbers.

## Done — swept and supported

59 designs: 41 external-IP families in `sweep-ext.yml` (manifests are
`test/ext_ip/<name>.json`) and 18 with a workflow of their own.

| Design | Repo | Swept by |
|---|---|---|
| Adams Bridge | [chipsalliance/adams-bridge](https://github.com/chipsalliance/adams-bridge) | `adams-bridge.json` (`sweep-ext.yml`) |
| AIB PHY hardware v2.0 | [chipsalliance/aib-phy-hardware](https://github.com/chipsalliance/aib-phy-hardware) | `aib-phy-hardware.json` (`sweep-ext.yml`) |
| AIB protocols | [chipsalliance/aib-protocols](https://github.com/chipsalliance/aib-protocols) | `aib-protocols.json` (`sweep-ext.yml`) |
| Alex Forencich verilog-ethernet | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | `verilog-ethernet.json` (`sweep-ext.yml`) |
| Alex Forencich verilog-pcie | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) | `verilog-pcie.json` (`sweep-ext.yml`) |
| Ariane CVA6 | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | `sweep-cva6.yml` |
| Ariane CVA6 (3 other configurations) | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | `sweep-cva6-flavours.yml` |
| biRISC-V | [ultraembedded/biriscv](https://github.com/ultraembedded/biriscv) | `biriscv.json` (`sweep-ext.yml`) |
| BlackParrot | [black-parrot/black-parrot](https://github.com/black-parrot/black-parrot) | `sweep-black-parrot.yml` |
| BOOM — LargeBoomV4 on rocket-chip DefaultConfig | [riscv-boom/riscv-boom](https://github.com/riscv-boom/riscv-boom) | `boom.json` (`sweep-ext.yml`) |
| Caliptra | [chipsalliance/caliptra-rtl](https://github.com/chipsalliance/caliptra-rtl) | `sweep-caliptra.yml` |
| Caliptra Subsystem | [chipsalliance/caliptra-ss](https://github.com/chipsalliance/caliptra-ss) | `caliptra-ss.json` (`sweep-ext.yml`) |
| Cheshire | [pulp-platform/cheshire](https://github.com/pulp-platform/cheshire) | `cheshire.json` (`sweep-ext.yml`) |
| chipsalliance/sv-tests conformance corpus | [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests) | `sweep-sv-tests.yml` |
| fx68k (68000) | [ijor/fx68k](https://github.com/ijor/fx68k) | `sweep-fx68k.yml` |
| Gemmini — LeanGemmini on rocket-chip DefaultConfig | [ucb-bar/gemmini](https://github.com/ucb-bar/gemmini) | `gemmini.json` (`sweep-ext.yml`) |
| Hazard3 | [Wren6991/Hazard3](https://github.com/Wren6991/Hazard3) | `hazard3.json` (`sweep-ext.yml`) |
| hdl-util hdmi | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | `hdmi.json` (`sweep-ext.yml`) |
| Ibex | [lowRISC/ibex](https://github.com/lowRISC/ibex) | `sweep-ibex.yml` |
| LiteX — the simulation SoC around VexRiscv | [enjoy-digital/litex](https://github.com/enjoy-digital/litex) | `litex.json` (`sweep-ext.yml`) |
| lowRISC Sonata system (CHERIoT-Ibex SoC) | [lowRISC/sonata-system](https://github.com/lowRISC/sonata-system) | `sonata-system.json` (`sweep-ext.yml`) |
| NaxRiscv | [SpinalHDL/NaxRiscv](https://github.com/SpinalHDL/NaxRiscv) | `naxriscv.json` (`sweep-ext.yml`) |
| NVDLA | [nvdla/hw](https://github.com/nvdla/hw) | `nvdla.json` (`sweep-ext.yml`) |
| OpenC910 | [XUANTIE-RV/openc910](https://github.com/XUANTIE-RV/openc910) | `openc910.json` (`sweep-ext.yml`) |
| OpenE906 | [XUANTIE-RV/opene906](https://github.com/XUANTIE-RV/opene906) | `opene906.json` (`sweep-ext.yml`) |
| OpenHW CORE-V MCU | [openhwfoundation/core-v-mcu](https://github.com/openhwfoundation/core-v-mcu) | `core-v-mcu.json` (`sweep-ext.yml`) |
| OpenHW CORE-V Wally | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | `cvw.json` (`sweep-ext.yml`) |
| OpenHW CV32E40P | [openhwfoundation/cv32e40p](https://github.com/openhwfoundation/cv32e40p) | `cv32e40p.json` (`sweep-ext.yml`) |
| OpenHW CV32E40S | [openhwfoundation/cv32e40s](https://github.com/openhwfoundation/cv32e40s) | `cv32e40s.json` (`sweep-ext.yml`) |
| OpenHW CV32E40X | [openhwfoundation/cv32e40x](https://github.com/openhwfoundation/cv32e40x) | `cv32e40x.json` (`sweep-ext.yml`) |
| OpenHW CVE2 | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | `cve2.json` (`sweep-ext.yml`) |
| OpenHW CVFPU | [openhwfoundation/cvfpu](https://github.com/openhwfoundation/cvfpu) | `cvfpu.json` (`sweep-ext.yml`) |
| OpenPiton | [PrincetonUniversity/openpiton](https://github.com/PrincetonUniversity/openpiton) | `openpiton.json` (`sweep-ext.yml`) |
| OpenTitan (vendored blocks) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) | `sweep-opentitan.yml` |
| OpenTitan IP blocks (upstream) | [lowRISC/opentitan.git](https://github.com/lowRISC/opentitan.git) | `opentitan-ip.json` (`sweep-ext.yml`) |
| Pavona (OpenTitan fork) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) | `sweep-pavona.yml` |
| PULP APB | [pulp-platform/apb](https://github.com/pulp-platform/apb) | `apb.json` (`sweep-ext.yml`) |
| PULP AXI | [pulp-platform/axi](https://github.com/pulp-platform/axi) | `axi.json` (`sweep-ext.yml`) |
| PULP common_cells | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) | `common_cells.json` (`sweep-ext.yml`) |
| PULP register_interface | [pulp-platform/register_interface](https://github.com/pulp-platform/register_interface) | `register_interface.json` (`sweep-ext.yml`) |
| PULP tech_cells_generic | [pulp-platform/tech_cells_generic](https://github.com/pulp-platform/tech_cells_generic) | `tech_cells_generic.json` (`sweep-ext.yml`) |
| PULPissimo | [pulp-platform/pulpissimo](https://github.com/pulp-platform/pulpissimo) | `pulpissimo.json` (`sweep-ext.yml`) |
| RgGen | [rggen/rggen-sv-rtl](https://github.com/rggen/rggen-sv-rtl) | `sweep-rggen.yml` |
| Rocket Chip — DefaultConfig | [chipsalliance/rocket-chip](https://github.com/chipsalliance/rocket-chip) | `rocket-chip.json` (`sweep-ext.yml`) |
| rp32 | [jeras/rp32](https://github.com/jeras/rp32) | `sweep-rp32.yml` |
| RSD | [rsd-devel/rsd](https://github.com/rsd-devel/rsd) | `sweep-rsd.yml` |
| SERV | [olofk/serv](https://github.com/olofk/serv) | `serv.json` (`sweep-ext.yml`) |
| Snitch cluster | [pulp-platform/snitch_cluster](https://github.com/pulp-platform/snitch_cluster) | `snitch.json` (`sweep-ext.yml`) |
| Syntacore SCR1 | [syntacore/scr1](https://github.com/syntacore/scr1) | `sweep-scr1.yml` |
| TNoC | [taichi-ishitani/tnoc](https://github.com/taichi-ishitani/tnoc) | `sweep-tnoc.yml` |
| VeeR EH1 | [chipsalliance/Cores-VeeR-EH1](https://github.com/chipsalliance/Cores-VeeR-EH1) | `sweep-veer-eh1.yml` |
| VeeR EH2 | [chipsalliance/Cores-VeeR-EH2](https://github.com/chipsalliance/Cores-VeeR-EH2) | `sweep-veer-eh2.yml` |
| VeeR EL2 | [chipsalliance/Cores-VeeR-EL2](https://github.com/chipsalliance/Cores-VeeR-EL2) | `sweep-veer-el2.yml` |
| VeeRwolf | [chipsalliance/VeeRwolf](https://github.com/chipsalliance/VeeRwolf) | `veerwolf.json` (`sweep-ext.yml`) |
| VexRiscv | [SpinalHDL/VexRiscv](https://github.com/SpinalHDL/VexRiscv) | `vexriscv.json` (`sweep-ext.yml`) |
| VTA — the DefaultDe10Config accelerator | [apache/tvm-vta](https://github.com/apache/tvm-vta) | `vta.json` (`sweep-ext.yml`) |
| XiangShan Kunminghu core (Chisel-generated) | [OpenXiangShan/XiangShan](https://github.com/OpenXiangShan/XiangShan) | `sweep-xiangshan.yml` |
| XiangShan XS-Verilog-Library | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) | `xiangshan.json` (`sweep-ext.yml`) |
| ZipCPU | [ZipCPU/zipcpu](https://github.com/ZipCPU/zipcpu) | `zipcpu.json` (`sweep-ext.yml`) |

## To do

| Candidate | Repo | What it needs |
|---|---|---|
| **cv32e41p** | [openhwfoundation/cv32e41p](https://github.com/openhwfoundation/cv32e41p) | The manifest is written (`test/ext_ip/cv32e41p.json`, the cv32e40x shape over a separate checkout) and the survey reads 23 / 23 with 0 undriven — but it is **not committed and not in the matrix**.  The next thing to land. |
| **OpenTitan `top_earlgrey`** | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) | Closure is solved — walk the CAPI=2 `.core` graph directly (635 files, 0 unresolved, 0 syntax errors with `-DSYNTHESIS`; one Surelog error on `alert_handler`'s `AsyncOn`).  The blocker is size: `read_uhdm` needs **11.9 GB** to read it, 13.5 GB with flatten+check, so a 16 GB nightly runner cannot hold it.  Needs its own sharded workflow and a flat shim for its interface-free top before it can carry formal and co-sim columns.  10 `Reference to unknown signal` warnings are untriaged. |
| **BlackParrot whole-core rows** | [black-parrot/black-parrot](https://github.com/black-parrot/black-parrot) | Twelve rows (`bp_processor`, `bp_unicore*`, `bp_core*`, `bp_multicore`, `bp_cacc_tile_node`) exceed the runner's 12 GB Surelog cap.  Measured and unresolved; the family's per-module rows are swept. |
| **i3c-core (standalone)** | [chipsalliance/i3c-core](https://github.com/chipsalliance/i3c-core) | **Low priority — already measured twice**: caliptra-ss sweeps its vendored copy and the OpenTitan library its own `i3c_*` rows.  A standalone row set at upstream head adds only freshness. |
| **NEORV32** | [stnolting/neorv32](https://github.com/stnolting/neorv32) | **Out of scope**: VHDL only, which a SystemVerilog frontend cannot read.  Listed so it is not asked about again. |
| **SweRVolf / Caravel SweRV** | [chipsalliance/VeeRwolf](https://github.com/chipsalliance/VeeRwolf) | **Covered**: SoC harnesses around cores already swept, and VeeRwolf itself is in the DONE table. |

## The rule that still holds

Land the manifest and read the first nightly **before** fixing anything it
finds.  A first sweep's value is the inventory it produces, and a defect a row
finds is cheaper to fix once that row is reproducible in CI.
