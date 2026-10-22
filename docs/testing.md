# Testing

The test framework, how to run it, how known failures are tracked, and what CI
runs.  The methodology behind the checks is in [verification.md](verification.md).
Back to the [README](../README.md).


## Test Structure
Each test case is a directory containing:
- `dut.sv` - SystemVerilog design under test
- Automatically generated comparison files:
  - `*_from_uhdm.il` - RTLIL generated via UHDM path
  - `*_from_verilog.il` - RTLIL generated via Verilog path
  - `rtlil_diff.txt` - Detailed RTLIL comparison
  - `*_from_uhdm_synth.v` - Gate-level netlist via UHDM path
  - `*_from_verilog_synth.v` - Gate-level netlist via Verilog path
  - `netlist_diff.txt` - Gate-level netlist comparison

## Running Tests
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

## Yosys Test Integration

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

## Verilator-based Simulation Equivalence Check

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

## Test Categories

The internal suite spans flip-flops & registers, counters, combinational/boolean/
arithmetic logic, multiplexers, multipliers & pipelines, state machines, functions,
scope & variable shadowing, arrays & memory, data types & structs, generate &
parameterization, module hierarchy & interfaces, and primitives.

**See [`docs/test-cases.md`](test-cases.md) for the full annotated catalog.**

## Test Management

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
[Test suite status](verification.md#test-suite-status). In short: the
internal SystemVerilog suite passes with 0 true failures / 0 crashes, and
`failing_tests.txt` documents the known expected-fail cases from the imported
upstream-Yosys suite (feature gaps, non-DUT techmap files, and equiv_induct
incompleteness that the SAT miter proves equivalent) — it is **not** empty.

## Important Test Workflow Note

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

## Continuous integration

GitHub Actions run four kinds of jobs (all on 16 GB GitHub-hosted runners, the
build cached by commit):

- **`ci.yml`** — the PR gate: builds Surelog, Yosys (+ `read_slang`) and the
  plugin, then runs the internal suite.
- **`regression-sharded.yml`** — the full `make test-all --all` suite plus the
  CVA6 per-module ratchet, split into 12 shards and merged into one report
  (every PR and nightly); the numbers under *Test Suite Status* come from it.
- **`frontend-matrix.yml`** — the nightly 4-frontend comparison behind
  [benchmarking.md](benchmarking.md).
- **`sweep-*.yml`** (one per family, the badges at the top) — the nightly per-IP sweeps
  (formal vs `read_slang`, opt-check, Verilator co-sim; sharded, memory-capped)
  whose tables feed the *Supported Core IP* rows and `pavona_sweep.md`.

## Project structure

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
