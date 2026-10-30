# UHDM to RTLIL Frontend

**Gates** (every PR + nightly) — a PR lands only on a clean run:

[![CI](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml) [![Regression (sharded)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml) [![Frontend matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml)

**Nightly IP sweeps** — one badge per sweep workflow, in the order [docs/supported_ip.md](docs/supported_ip.md) lists them; each links to its per-module report:

[![ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) [![rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) [![fx68k](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-fx68k.yml) [![scr1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-scr1.yml) [![rggen](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rggen.yml) [![veer-eh1](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh1.yml) [![tnoc](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-tnoc.yml) [![veer-el2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-el2.yml) [![veer-eh2](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh2.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-veer-eh2.yml) [![rsd](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rsd.yml) [![black-parrot](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-black-parrot.yml) [![opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) [![pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) [![cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) [![cva6 flavours](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6-flavours.yml) [![caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) [![xiangshan core](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-xiangshan.yml) [![external IP](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) [![sv-tests](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml/badge.svg?branch=main)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-sv-tests.yml)

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
# synthesize one of the regression tests (any .sv works the same way)
./out/current/bin/yosys -m build/uhdm2rtlil.so -p "read_sv -parse -nobuiltin test/simple_counter/dut.sv; synth -top simple_counter"
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
| [To do: cores and IP to bring under the sweeps](docs/todo.md) | what is not swept yet, what blocks each, and how it would be swept |

## Supported core IP

Upstream RTL imported verbatim and swept nightly -- formal equivalence against
`read_slang`, an opt-check for dropped drivers, and Verilator co-simulation of
both netlists against the RTL.  Results, scopes and commits are in
[docs/supported_ip.md](docs/supported_ip.md); the badges above are the sweeps.

**Total tally** (every PR runs the first two; the sweeps run nightly):

| | designs / rows | passing | measured by |
|---|---:|---:|---|
| Internal SystemVerilog tests | 1376 | 1340 functional, 0 true failures | the regression (`run_parallel.sh`), [docs/verification.md](docs/verification.md) |
| Upstream Yosys tests | 515 | 504 functional, 11 recorded failures | the same regression |
| Sweep rows (19 nightly workflows) | 8786 | 7162 formally proven, 7094 co-sim passes, 0 undriven; **11 open co-sim leads** — NVDLA 3 (`SDP_CORE_Y_cvt`, `_cvt_core`, `MRDMA_EG_dout`), OpenPiton 7, OpenC910 1, plus 29 NVDLA rows with no `read_slang` oracle.  2026-10-28 nightlies, except BOOM, Gemmini, Rocket Chip and biRISC-V, whose shards failed and whose entries below are their first local sweep | the per-core sweeps, [docs/benchmarking.md](docs/benchmarking.md) |
| **All** | **10677** | | |

- RISC-V cores: [Ibex](https://github.com/lowRISC/ibex), [rp32](https://github.com/jeras/rp32), [Syntacore SCR1](https://github.com/syntacore/scr1), [VeeR EH1](https://github.com/chipsalliance/Cores-VeeR-EH1), [VeeR EL2](https://github.com/chipsalliance/Cores-VeeR-EL2), [RSD](https://github.com/rsd-devel/rsd), [BlackParrot](https://github.com/black-parrot/black-parrot), [Ariane CVA6](https://github.com/openhwgroup/cva6) (four configurations), [XiangShan core](https://github.com/OpenXiangShan/XiangShan) (Chisel-generated), [CVE2](https://github.com/openhwgroup/cve2), [CV32E40P](https://github.com/openhwfoundation/cv32e40p), [CV32E40X](https://github.com/openhwfoundation/cv32e40x), [CV32E40S](https://github.com/openhwfoundation/cv32e40s), [CORE-V MCU](https://github.com/openhwfoundation/core-v-mcu), [CORE-V Wally](https://github.com/openhwgroup/cvw), [OpenC910](https://github.com/XUANTIE-RV/openc910), [OpenE906](https://github.com/XUANTIE-RV/opene906), [BOOM](https://github.com/riscv-boom/riscv-boom), [Rocket Chip](https://github.com/chipsalliance/rocket-chip), [OpenPiton](https://github.com/PrincetonUniversity/openpiton), [biRISC-V](https://github.com/ultraembedded/biriscv), [ZipCPU](https://github.com/ZipCPU/zipcpu), [Hazard3](https://github.com/Wren6991/Hazard3), [SERV](https://github.com/olofk/serv), [VexRiscv](https://github.com/SpinalHDL/VexRiscv), [NaxRiscv](https://github.com/SpinalHDL/NaxRiscv), [LiteX](https://github.com/enjoy-digital/litex)
- Other CPUs and SoCs: [fx68k](https://github.com/ijor/fx68k) (Motorola 68000), [Caliptra](https://github.com/chipsalliance/caliptra-rtl) and [caliptra-ss](https://github.com/chipsalliance/caliptra-ss), [Pavona](https://github.com/pavona/pavona) (27 IPs + 2 full chips)
- IP libraries: [OpenTitan](https://github.com/lowRISC/opentitan) (OTBN and the 44 other IP blocks), [RgGen](https://github.com/rggen/rggen-sv-rtl), [TNoC](https://github.com/taichi-ishitani/tnoc), [PULP AXI](https://github.com/pulp-platform/axi) and [common_cells](https://github.com/pulp-platform/common_cells), [CVFPU](https://github.com/openhwfoundation/cvfpu), [hdl-util HDMI](https://github.com/hdl-util/hdmi), [verilog-ethernet](https://github.com/alexforencich/verilog-ethernet), [verilog-pcie](https://github.com/alexforencich/verilog-pcie), [XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library)
- Accelerators: [NVDLA](https://github.com/nvdla/hw) (NVIDIA's deep-learning accelerator, 914 rows), [Gemmini](https://github.com/ucb-bar/gemmini) (the systolic-array GEMM accelerator as a RoCC on Rocket Chip)
- Conformance: [chipsalliance/sv-tests](https://github.com/chipsalliance/sv-tests), the LRM-chapter corpus

## Contributing

This frontend is developed with an AI coding agent, and that is how we
prefer contributions too: have your agent (Claude Code is what the project
uses; the checked-in skill
[`.claude/skills/verify-uhdm-equivalence`](.claude/skills/verify-uhdm-equivalence/SKILL.md)
loads automatically in this repository) take a divergence from symptom to a
fully vetted fix.  A pull request is accepted on the same bar whoever wrote
it:

- **one change** -- one reader defect, one harness change, or one document;
- **a test case and/or a sweep**: a `test/<name>/` with a `dut.sv` and its
  gates (`test_structural.ys` / `test_slang_equiv.ys`) that FAILS without the
  change and passes with it, and, when the defect came from third-party RTL,
  the sweep that keeps measuring it (an entry in `test/ext_ip/<family>.json`
  or a per-core sweep);
- **vetted with the skill's verification process**: frontend workflow,
  Verilator co-sim, `equiv_induct`, the sound SAT-from-reset miter, the sweep
  row re-measured, and a green full local regression
  (`cd test && ./run_parallel.sh 6 --no-cva6`);
- a commit message that states symptom, cause, fix, test and row, and ends
  with `Prepared with the assistance of Claude Code.` (the CLA bot rejects
  other trailers).

Hand-written contributions are welcome under the same bar.  Setup, the
debug-to-fix method and the review checklist are in
[docs/development.md](docs/development.md).

## License

See `LICENSE` file for details.

## Related Projects

- [Yosys](https://github.com/YosysHQ/yosys) - Open source synthesis suite
- [Surelog](https://github.com/chipsalliance/Surelog) - SystemVerilog parser
- [UHDM](https://github.com/chipsalliance/UHDM) - Universal Hardware Data Model
- [sv-elab / yosys-slang](https://github.com/povik/yosys-slang) and [slang](https://github.com/MikePopoloski/slang) - the `read_slang` frontend used as the formal reference for SV-only designs
- [sv2v](https://github.com/zachjs/sv2v) - SystemVerilog-to-Verilog converter, the third column of the frontend matrix
- [Verilator](https://github.com/verilator/verilator) - the co-simulation engine behind every co-sim result
- Verified IP: the cores, SoCs, IP libraries and the conformance corpus listed under [Supported core IP](#supported-core-ip) above
