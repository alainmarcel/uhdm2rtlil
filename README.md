# UHDM to RTLIL Frontend

**Gates** (every PR + nightly) — a PR lands only on a clean run:

[![CI](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml) [![Regression (sharded)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml) [![Frontend matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml)

**Nightly IP sweeps** — one badge per sweep workflow, in the order [docs/supported_ip.md](docs/supported_ip.md) lists them; each links to its per-module report:

[![ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) [![rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) [![fx68k](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml) [![scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml) [![rggen](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml) [![veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml) [![tnoc](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml) [![veer-el2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml) [![rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml) [![black-parrot](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml) [![opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) [![pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) [![cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) [![cva6 flavours](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml) [![caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) [![xiangshan core](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml) [![external IP](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) [![sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language). Focused on creating post-synthesis (Gate-level) netlists that matches RTL simulation using Verilator as the golden standard.

> ### ✅ Every result is verified
> Nothing here is counted as "working" on a read-only or vacuous pass. Every
> synthesized netlist is proven correct by **formal equivalence** — Yosys
> `equiv_induct` plus a sound **SAT-from-reset miter** against the Yosys
> Verilog-frontend golden — **and/or** by **high-activity randomized Verilator
> co-simulation** against the original RTL. A SAT miter also adjudicates every
> divergence so an inductive-proof gap is never mistaken for a real bug.
> See **[docs/verification.md](docs/verification.md)**.

## Quick Start

`SystemVerilog (.sv) → [Surelog] → UHDM → [UHDM Frontend] → RTLIL → [Yosys] → Netlist`

Two components: **Surelog** parses and elaborates SystemVerilog into UHDM, and
the **UHDM Frontend** (this repository, `src/frontends/uhdm/`) imports the
elaborated model into Yosys RTLIL.  The plugin adds two Yosys commands,
`read_sv` (in-process Surelog compile, recommended) and `read_uhdm` (a
pre-generated `.uhdm` file):

```bash
git clone --recursive https://github.com/alainmarcel/uhdm2rtlil.git && cd uhdm2rtlil
git config core.hooksPath .githooks
make                                  # Surelog, Yosys (+ read_slang) and the plugin
./out/current/bin/yosys -m build/uhdm2rtlil.so -p "read_sv -parse -nobuiltin design.sv; synth -top top_module"
```

Prerequisites (GCC ≥ 11, CMake 3.28–3.31, Verilator 5.x) and the full command
reference are in [docs/getting_started.md](docs/getting_started.md).

## Documentation

| | |
|---|---|
| [Getting started](docs/getting_started.md) | prerequisites, build, `read_sv` / `read_uhdm` usage |
| [Verification methodology & test-suite status](docs/verification.md) | formal equivalence, the SAT-from-reset miter, Verilator co-sim; the regression numbers |
| [Supported core IP](docs/supported_ip.md) | every swept core and IP family with its measured result |
| [Benchmarking](docs/benchmarking.md) | per-core co-simulation vs `read_slang`, the reference frontend's own record, the 4-frontend matrix |
| [Architecture & supported SystemVerilog](docs/architecture.md) | the importer's components and the language features it handles |
| [Testing](docs/testing.md) | test structure, running the suites and sweeps, known-failure lists, CI, project layout |
| [Development](docs/development.md) | adding a construct, debugging, the AI-assisted workflow, contributing |
| [Changelog](docs/recent-improvements.md) | the annotated list of landed features and fixes |
| [Test catalog](docs/test-cases.md) | every internal test, incl. the UHDM-only list |
| [sv-tests coverage](docs/sv_tests_coverage.md) | chipsalliance/sv-tests per test: read_uhdm vs read_verilog vs read_slang |
| [What `read_slang` cannot read](docs/slang_unsupported.md) · [incomplete test cases](docs/incomplete_testcases.md) | the reference frontend's failures with reproduce recipes; tests no frontend can be judged on |
| [Pavona per-IP table](docs/pavona_sweep.md) · [External IP families](docs/ext_ip.md) | the two sub-tables behind their sweep rows |

## Supported core IP

Upstream RTL imported verbatim and swept nightly -- formal equivalence against
`read_slang`, an opt-check for dropped drivers, and Verilator co-simulation of
both netlists against the RTL.  Results, scopes and commits are in
[docs/supported_ip.md](docs/supported_ip.md); the badges above are the sweeps.

- RISC-V cores: [Ibex](https://github.com/lowRISC/ibex), [rp32](https://github.com/jeras/rp32), [Syntacore SCR1](https://github.com/syntacore/scr1), [VeeR EH1](https://github.com/chipsalliance/Cores-VeeR-EH1), [VeeR EL2](https://github.com/chipsalliance/Cores-VeeR-EL2), [RSD](https://github.com/rsd-devel/rsd), [BlackParrot](https://github.com/black-parrot/black-parrot), [Ariane CVA6](https://github.com/openhwgroup/cva6) (four configurations), [XiangShan core](https://github.com/OpenXiangShan/XiangShan) (Chisel-generated), [CVE2](https://github.com/openhwgroup/cve2), [CV32E40P](https://github.com/openhwfoundation/cv32e40p), [CORE-V Wally](https://github.com/openhwgroup/cvw)
- Other CPUs and SoCs: [fx68k](https://github.com/ijor/fx68k) (Motorola 68000), [Caliptra](https://github.com/chipsalliance/caliptra-rtl) and [caliptra-ss](https://github.com/chipsalliance/caliptra-ss), [Pavona](https://github.com/pavona/pavona) (27 IPs + 2 full chips)
- IP libraries: [OpenTitan](https://github.com/lowRISC/opentitan) (OTBN and the 44 other IP blocks), [RgGen](https://github.com/rggen/rggen-sv-rtl), [TNoC](https://github.com/taichi-ishitani/tnoc), [PULP AXI](https://github.com/pulp-platform/axi) and [common_cells](https://github.com/pulp-platform/common_cells), [CVFPU](https://github.com/openhwfoundation/cvfpu), [hdl-util HDMI](https://github.com/hdl-util/hdmi), [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet), [verilog-pcie](https://github.com/alexforencich/verilog-pcie), [XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library)
- Conformance: [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests), the LRM-chapter corpus

## Contributing

Fork, set the git hooks (`git config core.hooksPath .githooks`), add a test
next to your change, run `cd test && ./run_parallel.sh 6 --no-cva6`, and open
a pull request -- details in [docs/development.md](docs/development.md).

## License

See `LICENSE` file for details.

## Related Projects

- [Yosys](https://github.com/YosysHQ/yosys) - Open source synthesis suite
- [Surelog](https://github.com/chipsalliance/Surelog) - SystemVerilog parser
- [UHDM](https://github.com/chipsalliance/UHDM) - Universal Hardware Data Model
- [sv-elab / yosys-slang](https://github.com/povik/yosys-slang) and [slang](https://github.com/MikePopoloski/slang) - the `read_slang` frontend used as the formal reference for SV-only designs
- [sv2v](https://github.com/zachjs/sv2v) - SystemVerilog-to-Verilog converter, the third column of the frontend matrix
- [Verilator](https://github.com/verilator/verilator) - the co-simulation engine behind every co-sim result
- Verified IP (upstream RTL swept nightly, see [docs/supported_ip.md](docs/supported_ip.md)): [Ibex](https://github.com/lowRISC/ibex), [rp32](https://github.com/jeras/rp32), [fx68k](https://github.com/ijor/fx68k), [Syntacore SCR1](https://github.com/syntacore/scr1), [RgGen](https://github.com/rggen/rggen-sv-rtl), [VeeR EH1](https://github.com/chipsalliance/Cores-VeeR-EH1) and [EL2](https://github.com/chipsalliance/Cores-VeeR-EL2), [TNoC](https://github.com/taichi-ishitani/tnoc), [RSD](https://github.com/rsd-devel/rsd), [BlackParrot](https://github.com/black-parrot/black-parrot), [OpenTitan](https://github.com/lowRISC/opentitan), [Pavona](https://github.com/pavona/pavona), [CVA6](https://github.com/openhwgroup/cva6), [Caliptra](https://github.com/chipsalliance/caliptra-rtl) and [caliptra-ss](https://github.com/chipsalliance/caliptra-ss), [XiangShan](https://github.com/OpenXiangShan/XiangShan) and its [Verilog library](https://github.com/OpenXiangShan/XS-Verilog-Library), [CVE2](https://github.com/openhwgroup/cve2), [CV32E40P](https://github.com/openhwfoundation/cv32e40p), [CVFPU](https://github.com/openhwfoundation/cvfpu), [CORE-V Wally](https://github.com/openhwgroup/cvw), [PULP AXI](https://github.com/pulp-platform/axi) and [common_cells](https://github.com/pulp-platform/common_cells), [hdl-util HDMI](https://github.com/hdl-util/hdmi), [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet), [verilog-pcie](https://github.com/alexforencich/verilog-pcie), and the [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests) conformance corpus
