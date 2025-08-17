# Running Yosys Tests with UHDM Frontend

This document describes how to run the Yosys test suite with the UHDM frontend.

## Overview

We've created infrastructure to run tests from `third_party/yosys/tests/` using the UHDM frontend. The tests are run in a read-only manner - we don't modify anything in the Yosys test directory. Instead, all temporary files are created under `test/run/`.

## Scripts

### `run_yosys_tests.sh`
This script runs Yosys tests with the UHDM frontend. It:
- Treats `third_party/yosys/tests/` as read-only
- Creates test directories under `test/run/<dir_name>/<test_name>/`
- Runs both Verilog and UHDM frontends
- Performs formal equivalence checking when both succeed
- Categorizes results as:
  - ✅ Passed (equivalent outputs)
  - 🚀 UHDM-only success (Verilog fails but UHDM works)
  - ❌ Failed (UHDM fails or outputs differ)
  - ⚠️ Skipped (both frontends fail)

### `run_all_tests.sh`
Enhanced test runner that can run:
- Local tests only (default)
- Yosys tests only (`--yosys`)
- Both test suites (`--all`)

## Usage

```bash
# Run all local tests
./test/run_all_tests.sh

# Run specific local test
./test/run_all_tests.sh simple_memory

# Run all Yosys tests
./test/run_all_tests.sh --yosys

# Run specific Yosys tests
./test/run_all_tests.sh --yosys "memories/simple"

# Run both test suites
./test/run_all_tests.sh --all
```

## Test Directory Structure

For each Yosys test, we create:
```
test/run/
├── <dir_name>/
│   └── <test_name>/
│       ├── dut.sv                           # Copy of original test
│       ├── test_verilog_read.ys            # Yosys script for Verilog
│       ├── test_uhdm_read.ys               # Yosys script for UHDM
│       ├── verilog_path.log                 # Verilog frontend log
│       ├── uhdm_path.log                    # UHDM frontend log
│       ├── surelog.log                      # Surelog log
│       ├── slpp_all/surelog.uhdm           # UHDM file from Surelog
│       ├── <test>_from_verilog.il          # RTLIL from Verilog
│       ├── <test>_from_uhdm.il             # RTLIL from UHDM
│       ├── <test>_from_verilog_synth.v     # Synthesized from Verilog
│       ├── <test>_from_uhdm_synth.v        # Synthesized from UHDM
│       └── equiv_check.log                  # Equivalence check log
```

## Current Status

The infrastructure is complete and working. However, there are several issues with the UHDM frontend that need to be fixed:

1. **Combinational always blocks**: The frontend incorrectly treats `always @*` as clocked blocks, causing assertion failures
2. **Memory handling**: Some memory tests cause segmentation faults
3. **Case statements**: Case statements in synchronous context are not yet implemented

These issues need to be resolved before the Yosys test suite can be run successfully.

## Test Selection

The script automatically identifies self-contained Verilog/SystemVerilog tests by:
- Checking for `.v` or `.sv` extension
- Verifying the file contains a module declaration
- Skipping files with `include directives (not self-contained)
- Skipping header files (`.vh`, `_inc.v`, `_include.v`)

## Next Steps

1. Fix the combinational always block handling (always @*)
2. Debug and fix memory-related crashes
3. Implement case statement support in synchronous context
4. Run the full Yosys test suite and analyze results