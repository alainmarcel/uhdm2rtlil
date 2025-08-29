# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Yosys frontend that converts SystemVerilog to RTLIL (Register Transfer Level Intermediate Language) via UHDM (Universal Hardware Data Model). The workflow is: SystemVerilog → Surelog → UHDM → UHDM Frontend → RTLIL → Yosys synthesis.

## Build Commands

```bash
# Standard build (Release mode)
make -j$(nproc)

# Debug build with detailed logging
make debug

# Rebuild after changing source files
cd build && make -j$(nproc)

# Quick rebuild of just the plugin
cd build && make uhdm2rtlil -j$(nproc)

# Full clean rebuild
make clean && make -j$(nproc)
```

## Running Tests

```bash
# Run a single test
cd test && ./test_uhdm_workflow.sh <test_name>
# Example: ./test_uhdm_workflow.sh simple_counter

# Run a test with debugging enabled
cd test/<test_name> && YOSYS_ENABLE_UHDM_DEBUG=1 ../../out/current/bin/yosys -m ../../build/uhdm2rtlil.so -p "read_uhdm slpp_all/surelog.uhdm"

# Run all internal tests
cd test && ./run_all_tests.sh

# Run formal equivalence check on a specific test
cd test && ./test_equivalence.sh <test_name>

# Generate UHDM from SystemVerilog for a test
cd test/<test_name> && /home/alain/uhdm2rtlil/build/third_party/Surelog/bin/surelog -parse -d uhdm dut.sv

# Run Yosys with UHDM frontend
cd test/<test_name> && ../../out/current/bin/yosys -m ../../build/uhdm2rtlil.so -p "read_uhdm slpp_all/surelog.uhdm; write_rtlil test.il"
```

## Architecture

### Core Components

The UHDM frontend is in `src/frontends/uhdm/` with these key files:

- **uhdm2rtlil.cpp/h**: Main entry point, UHDM design traversal, module hierarchy management
  - Contains `UhdmImporter` class with the main import flow
  - Key data structures: `name_map` (signal mapping), `gen_scope_stack` (generate blocks), `loop_values` (for loop variables)

- **module.cpp**: Module instantiation, port connections, wire/reg declarations
  - `import_module()`: Main module import function
  - `import_generate_scope()`: Handles generate blocks
  - Wire creation with proper escaping for special characters

- **process.cpp**: Always blocks, if-else, case statements, procedural assignments
  - `import_process()`: Converts always blocks to RTLIL processes
  - Handles clock/reset inference for flip-flops
  - Creates sync rules and switch statements

- **expression.cpp**: All expression evaluation - operators, parameters, references
  - `import_expression()`: Main expression handler
  - Parameter resolution including HEX/BIN formats
  - Loop variable substitution in generate blocks

- **memory.cpp** and **memory_analysis.cpp**: Memory inference and optimization
  - Detects memory patterns in always blocks
  - Handles asymmetric port RAMs
  - Shift register detection

### Key Patterns and Conventions

1. **Signal Naming**: 
   - Generate blocks create hierarchical names: `gen_loop[0].signal`
   - Escaped identifiers preserved: `\reset*`, `\q~`
   - Use `RTLIL::escape_id()` for all signal names

2. **Parameter Resolution**:
   - Parameters can have formats: `UINT:8`, `HEX:AA`, `BIN:1010`
   - Check `Actual()` and `Actual_group()` for parameter references
   - Fallback to `module->parameter_default_values`

3. **Generate Scope Management**:
   - Push/pop `gen_scope_stack` when entering/leaving generate blocks
   - Import both variables AND nets from generate scopes
   - Use `get_current_gen_scope()` for hierarchical naming

4. **Debug Mode**:
   - Enable with `YOSYS_ENABLE_UHDM_DEBUG=1` environment variable
   - Adds extensive logging of UHDM traversal
   - Shows parameter resolution and expression evaluation

## Common Issues and Solutions

### Test Failures
- Check `test/<test_name>/uhdm_path.log` for UHDM processing errors
- Compare `*_from_uhdm_nohier.il` vs `*_from_verilog_nohier.il` for differences
- Run with debug mode to trace parameter/expression issues

### Finding UHDM Types and Definitions

When working with UHDM objects, you need to know where to find type definitions:

1. **VPI Type Constants** (e.g., `vpiModule`, `vpiParameter`, `vpiOperation`):
   - Location: `third_party/Surelog/third_party/UHDM/include/vpi_user.h`
   - Contains all VPI standard type enums
   - Example: `#define vpiModule 32`, `#define vpiParameter 41`

2. **UHDM Object Class Definitions** (e.g., `module_inst`, `parameter`, `ref_obj`):
   - Location: `build/third_party/Surelog/third_party/UHDM/generated/uhdm/<object_name>.h`
   - Example: `build/third_party/Surelog/third_party/UHDM/generated/uhdm/module_inst.h`
   - Contains class methods like `VpiName()`, `Actual()`, `Actual_group()`, etc.

3. **UHDM Headers to Include**:
   - Main include: `#include <uhdm/uhdm.h>`
   - This pulls in all necessary UHDM types and the visitor pattern

4. **Inspecting UHDM Content**:
   - **Important**: To inspect the actual UHDM content for a test, look at the `uhdm_path.log` file
   - This file contains the textual representation of the UHDM tree that shows all objects and their properties
   - Located at: `test/<test_name>/uhdm_path.log`
   - Alternatively, use: `uhdm-dump slpp_all/surelog.uhdm` to manually dump UHDM content
   - The uhdm-dump tool is at: `build/third_party/Surelog/third_party/UHDM/bin/uhdm-dump`

### Adding New Features
1. Identify UHDM node type in the UHDM dump (use `-d uhdm` with Surelog)
2. Find the VPI type constant in `vpi_user.h` and object class in `generated/uhdm/`
3. Add handler in appropriate file (expression/process/module)
4. Create test case in `test/` directory
5. Run workflow test to validate equivalence

### Known Failing Tests
Listed in `test/failing_tests.txt`:
- `carryadd` - UHDM output missing
- `case_expr_const` - Expected failure
- `forloops` - Expected failure  
- `mem2reg_test1` - Equivalence failure

## Code Style

- Use RTLIL types consistently (`RTLIL::SigSpec`, `RTLIL::Wire`, etc.)
- Check `mode_debug` before logging
- Always escape identifiers with `RTLIL::escape_id()`
- Handle both `Actual()` and `Actual_group()` for references

## Testing Workflow

1. **Create test**: Add `dut.sv` in `test/<test_name>/`
2. **Generate UHDM**: Surelog automatically runs via workflow script
3. **Compare paths**: Script runs both UHDM and Verilog frontends
4. **Check equivalence**: Formal verification with Yosys SAT solver
5. **Debug differences**: Use diff tools on IL files and debug mode