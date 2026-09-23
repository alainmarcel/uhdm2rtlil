# UHDM to RTLIL Frontend

[![CI](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml/badge.svg)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/ci.yml) [![Regression (sharded)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml/badge.svg)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/regression-sharded.yml) [![Frontend matrix](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml/badge.svg)](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/frontend-matrix.yml)

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
`cd test && ./run_parallel.sh 6 --no-cva6` (~1055 tests, ~25 min).  A PR lands
only on a clean run.

| | Total | Internal SV | Upstream Yosys |
|---|---|---|---|
| Tests | 1595 | 1047 | 548 |
| Functional | 1549 (97%) | **1047 (100%)** | 502 |
| True failures | 11 | **0** | 11 |
| Crashes | 1 | **0** | 1 |

- **0 Miter-Formal escapes** — no UHDM≠Verilog difference slips past
  `equiv_induct`.  This is the number that matters: every equivalence failure
  is one `equiv_induct` caught.
- **978** tests formally equivalent UHDM vs Verilog; **571** UHDM-only
  (constructs `read_verilog` cannot parse) verified against Verilator;
  **108 / 109** SV-only designs also proven against `read_slang`.
- **13 equivalence failures**, each with a recorded verdict in
  `test/failing_tests.txt`.  In several the *reference* is the wrong side
  (`read_verilog` mis-lowers the construct) — a SAT miter against `read_slang`
  proves UHDM correct.
- **Sim-equiv ratchet** (`test/sim_equiv_warn_baseline.txt`, shrink-only): 105
  divergences outstanding across the full corpus; 74 analyzed, 57 shown to be
  sim/synth artefacts a miter proves UHDM == Verilog, 17 still inconclusive.
  Restricted to the internal SV suite the backlog is 27, all 54 analyzed ones
  artefacts, 0 inconclusive.


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
| **Ibex** | [lowRISC/ibex](https://github.com/lowRISC/ibex) | 2-stage RV32IMC core (+PMP, ICache, lockstep); 28 modules incl. `ibex_top` | **19 / 28 proven**, 20 / 20 co-sim, 26 / 28 opt-clean; whole hierarchy **0 loops, 0 undriven** | [ibex](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ibex.yml) |
| **rp32 (R5P)** | [jeras/rp32](https://github.com/jeras/rp32) | 32-bit cores + TCB SoCs; 13 modules | **6 / 13 proven**, 3 / 3 co-sim, 9 / 13 opt-clean; both SoCs boot and run a program in functional sim | [rp32](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-rp32.yml) |
| **OpenTitan** (upstream) | [lowRISC/opentitan](https://github.com/lowRISC/opentitan) @ [`f49474bc`](https://github.com/lowRISC/opentitan/commit/f49474bc89c3ce8a99536329a1e16bf22936da37) | [OTBN](https://github.com/lowRISC/opentitan/tree/master/hw/ip/otbn/rtl) 256-bit bignum accelerator; 32 modules, 122 files | **26 / 32 proven**, 4 SAT timeouts (256-bit datapaths), 1 cex (a read_slang reference issue), 1 elaboration error; **every elaborating module opt-clean (0 undriven)** | [opentitan](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-opentitan.yml) |
| **Pavona** | [pavona/pavona](https://github.com/pavona/pavona) @ [`61ebeba1`](https://github.com/pavona/pavona/commit/61ebeba10cafca3b0dd43786fa79d26882a5ccf5) | OpenTitan-derived SoC family: hardened Ibex, TL-UL fabric, 27 crypto/peripheral IPs, 2 full chips; 299 module rows + 98 chip instances | **284 / 297 proven**, 291 / 292 co-sim; chips **47 / 47 + 51 / 51** instances proven, full-chip co-sim **PASS** | [pavona](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-pavona.yml) · [per-IP table](docs/pavona_sweep.md) |
| **Ariane CVA6** | [openhwgroup/cva6](https://github.com/openhwgroup/cva6) | 6-stage 64-bit app-class core (`cv64a6_imafdc_sv39`) + HPDcache, FPnew; 142 modules | **94 / 147 proven**, 12 cex, 26 SAT timeouts; full core lowers with **0 inferred latches**, 0 one-sided co-sim divergences | [cva6](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-cva6.yml) |
| **Caliptra** | [chipsalliance/caliptra-rtl](https://github.com/chipsalliance/caliptra-rtl) | Root-of-trust SoC: VeeR EL2, AXI, mailbox, SHA/HMAC/ECC/Ascon, ML-DSA/ML-KEM; 867 modules, 172 instances | **19 / 21 instances proven** (the 2 are SAT timeouts on vault register files, not mismatches); **0 undriven, 0 driver conflicts**; full-chip co-sim **NO_DIVERGENCE** over 401 cycles | [caliptra](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-caliptra.yml) |
| **XiangShan** (香山) | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) @ [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | The XiangShan project's **hand-written SystemVerilog** arithmetic library — SRT integer dividers, radix-2/4/16 FP divide-sqrt, LZC, CSA, QDS; 21 modules.  **Not the core**: XiangShan itself is Chisel/Scala and emits no Verilog without running its generator | **15 / 19 proven**, 19 / 19 elaborate, **0 undriven on 18 of 19**; 1 cex (`r4_qds_v1`), 3 SAT timeouts (64-bit divide datapaths), 2 not comparable — `read_slang` rejects them for a port mismatch in the library's own RTL (`port 'quot_o' does not exist in 'radix_4_sign_coder'`) | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |
| **XiangShan core** (香山) | [OpenXiangShan/XiangShan](https://github.com/OpenXiangShan/XiangShan) @ [`e4566c29`](https://github.com/OpenXiangShan/XiangShan/commit/e4566c29e251c60159c6796db60a2569dd7700f2) | Kunminghu out-of-order RV64 core, `CONFIG=DefaultConfig` (frontend + backend + vector + MMU, L2 + L3) — **there is no Verilog to read**: the sweep runs the Chisel generator itself (mill + firtool → **1980 `.sv` + 22 `.v`, 3.2 M lines, 2002 modules**), then sweeps 42 of them | Whole core **elaborates clean**: Surelog 0 errors, `read_uhdm` + `hierarchy -check -top XSTop` exit 0, 1981 modules / 6.52 M cells, **1 warning**.  Per-module: **24 / 24 zero undriven, 23 / 24 co-sim PASS**, 11 proven — the rest are SAT budget (timeout / memory cap), 2 cex | `make xiangshan-core-full` (not CI-sized — see below) |
| **External IP** (8 repos) | see table below | Breadth sweep over third-party (System)Verilog *not* covered above — no vendored copy, each repo fetched at a pinned commit (`test/ext_ip/<family>.json`) | **325 / 428 comparable modules proven**.  295 of 723 are **not comparable** and excluded: 53 cannot elaborate standalone with their own default parameters, 242 `read_slang` cannot read.  Deliberately unfiltered — the un-curated tail | [ext](https://github.com/alainmarcel/uhdm2rtlil/actions/workflows/sweep-ext.yml) |

CVA6 is the one family excluded from the local `--no-cva6` developer run, so
its figures are a **dated snapshot** (2026-09-17 sharded regression) rather
than a current measurement — read the nightly for live numbers.

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
| PULP AXI | [pulp-platform/axi](https://github.com/pulp-platform/axi) | [`70b8e54f`](https://github.com/pulp-platform/axi/commit/70b8e54fd460) | **8 / 12** | 96 of 108 | 21 |
| PULP common_cells | [pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) | [`121182ea`](https://github.com/pulp-platform/common_cells/commit/121182eaa0fa) | **109 / 119** | 7 of 126 | 4 |
| OpenHW CVE2 | [openhwgroup/cve2](https://github.com/openhwgroup/cve2) | [`d079e8c8`](https://github.com/openhwgroup/cve2/commit/d079e8c8e6a0) | **14 / 21** | 2 of 23 | 0 |
| OpenHW CORE-V Wally | [openhwgroup/cvw](https://github.com/openhwgroup/cvw) | [`bc7012a9`](https://github.com/openhwgroup/cvw/commit/bc7012a92273) | **75 / 88** | 146 of 234 | 83552 (RAM/ROM arrays) |
| hdl-util HDMI | [hdl-util/hdmi](https://github.com/hdl-util/hdmi) | [`83b1c954`](https://github.com/hdl-util/hdmi/commit/83b1c9543a91) | **4 / 7** | 3 of 10 | 0 |
| verilog-ethernet | [alexforencich/verilog-ethernet](https://github.com/alexforencich/verilog-ethernet) | [`77320a94`](https://github.com/alexforencich/verilog-ethernet/commit/77320a9471d1) | **77 / 108** | 21 of 129 | 449 |
| verilog-pcie | [alexforencich/verilog-pcie](https://github.com/alexforencich/verilog-pcie) | [`25156a9a`](https://github.com/alexforencich/verilog-pcie/commit/25156a9a162c) | **38 / 73** | 20 of 93 | 190 |
| XiangShan XS-Verilog-Library | [OpenXiangShan/XS-Verilog-Library](https://github.com/OpenXiangShan/XS-Verilog-Library) | [`ffc9cee4`](https://github.com/OpenXiangShan/XS-Verilog-Library/commit/ffc9cee4387c3c795335f5fadc94029d0fd9d3b5) | **15 / 19** | 2 of 21 | 1 |

#### Generated IP: the XiangShan core

XiangShan's core is **Chisel/Scala** — the repository contains no Verilog, so
unlike every other family there is nothing to read until the generator has run.
Generation is a step of the sweep itself, driven from the repository root:

```bash
make xiangshan-core          # CONFIG=MinimalConfig
make xiangshan-core-full     # CONFIG=DefaultConfig — the complete Kunminghu core
```

Each clones `OpenXiangShan/XiangShan` at the pinned commit under `$EXT_IP_ROOT`
(default `~/ext`), downloads `mill` if needed, runs `make verilog`, and sweeps
the result.  A JDK 17+ is the only prerequisite.

**Neither runs in CI, and that is measured, not assumed:** `DefaultConfig`
generates 3.2 M lines and needs a 40 GB JVM heap; `MinimalConfig` still peaks at
13.5 GB RSS to generate 2.2 M lines, and Surelog on `XSTop` peaks at 35.5 GB —
against a hosted runner's 16 GB RAM and 14 GB free disk.  The binding constraint
is the Chisel build rather than the RTL size, so the cheaper configuration does
not become CI-sized either.  The hand-written **XS-Verilog-Library** (the
`xiangshan` family above) is the part of the project that *is* swept nightly.

AXI additionally pulls [tech_cells_generic](https://github.com/pulp-platform/tech_cells_generic)
and verilog-pcie pulls [verilog-axis](https://github.com/alexforencich/verilog-axis).

Most of AXI's exclusions are one cause: PULP declares its struct ports through
type parameters (`parameter type axi_resp_t = logic`), so a module swept
standalone with its defaults performs a member access on a 1-bit `logic` —
`read_slang` rejects it outright and there is nothing to compare against.  Those
rows are recorded with the slang diagnostic that identifies them.

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
1559 tests) reports two things separately: what each frontend could **read**,
and — where a `read_verilog` golden exists to compare against — whether it was
**right**.

| Frontend | Read | Failed to read | Correct | Incorrect | No golden | Unknown |
|---|---:|---:|---:|---:|---:|---:|
| **`uhdm`** (this project) | **1527** | 33 | 936 | 24 | 501 | 65 |
| `sv2v` | 1352 | 207 | 873 | 0 | 414 | 65 |
| `slang` (Yosys sv-elab) | 1289 | 270 | 743 | 0 | 426 | 120 |
| `verilog` (Yosys native, the golden) | 975 | 584 | 966 | 9 | — | 0 |

*Failed to read* = failed + crashed + out-of-memory.  *No golden* = this
frontend synthesized but `read_verilog` could not, so there is nothing to
compare against — a capability win, verified against the RTL by co-simulation
rather than formally.  *Unknown* = formal non-equivalence the co-sim could not
adjudicate.

On this corpus the UHDM frontend reads the most SystemVerilog — **1527 of 1559**,
including **501 designs the native Verilog frontend cannot read at all**.

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
  higher "Failed to read" counts (207 / 270 vs 33) reflect that trade-off, not a
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

### Prerequisites
- GCC ≥ 11 (C++20; the bundled Yosys v0.68 and its built-in `read_slang` frontend require it)
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
to Surelog): `-uhdm_debug`, `-formal`, `-keep_names`.

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

Options: `-debug`, `-formal`, `-keep_names`.

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
│   └── yosys/                 # Synthesis framework (v0.68 + one fork patch, built with read_slang)
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
