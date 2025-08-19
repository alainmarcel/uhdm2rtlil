# UHDM to RTLIL Frontend

![CI](https://github.com/username/uhdm2rtlil/workflows/CI/badge.svg)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language).

## Overview

This project bridges the gap between SystemVerilog source code and Yosys synthesis by leveraging two key components:

1. **Surelog** - Parses SystemVerilog and generates UHDM
2. **UHDM Frontend** - Converts UHDM to Yosys RTLIL

This enables full SystemVerilog synthesis capability in Yosys, including advanced features not available in Yosys's built-in Verilog frontend.

### Test Suite Status
- **Success Rate**: 100% (30/30 tests functional)
- **Perfect Matches**: 26 tests validated by formal equivalence checking
- **UHDM-Only Success**: 4 tests demonstrate superior SystemVerilog support
- **Functional**: All tests work correctly, validated by formal equivalence checking

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
  - Packed structures with member access via bit slicing
  - Struct arrays with complex indexing
  - Package types and imports
- **Procedural Blocks**: 
  - `always_ff` - Sequential logic with proper clock/reset inference
  - `always_comb` - Combinational logic
  - `always` - Mixed sequential/combinational logic
- **Expressions**: 
  - Arithmetic, logical, bitwise, comparison, ternary operators
  - Struct member access (e.g., `bus.field`)
  - Hierarchical signal references
  - Parameter references in expressions
- **Control Flow**: If-else statements, case statements with parameter values, loops
- **Memory**: Array inference, memory initialization
- **Generate Blocks**: For loops, if-else generate, hierarchical instance naming
- **Packages**: Import statements, package parameters, struct types, functions
- **Primitives**: Gate arrays (and, or, xor, nand, nor, xnor, not, buf)
- **Advanced Features**: 
  - Interfaces with automatic expansion to individual signals
  - Interface port connections and signal mapping
  - Assertions

## Quick Start

### Prerequisites
- GCC/Clang compiler with C++17 support
- CMake 3.16+
- Python 3.6+
- Standard development tools (make, bison, flex)

### Build
```bash
# Clone with submodules
git clone --recursive https://github.com/username/uhdm2rtlil.git
cd uhdm2rtlil

# Configure git hooks (prevents committing files >10MB)
git config core.hooksPath .githooks

# Build everything (Surelog, Yosys, UHDM Frontend)
make
```

### Basic Usage
```bash
# Method 1: Using the test workflow
cd test
bash test_uhdm_workflow.sh simple_counter

# Method 2: Manual workflow
# Step 1: Generate UHDM from SystemVerilog
./build/third_party/Surelog/bin/surelog -parse design.sv

# Step 2: Use Yosys with UHDM frontend (load plugin first)
./out/current/bin/yosys -p "plugin -i uhdm2rtlil.so; read_uhdm slpp_all/surelog.uhdm; synth -top top_module"
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
# Run internal tests only (our test suite)
make test

# Run all tests (internal + Yosys tests)
make test-all

# Run Yosys tests only
make test-yosys

# Run specific test from test directory
cd test
bash test_uhdm_workflow.sh simple_counter

# Run tests with options from test directory
cd test
bash run_all_tests.sh                    # Run internal tests only
bash run_all_tests.sh --all              # Run all tests (internal + Yosys)
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

The Yosys test runner:
- Automatically finds self-contained Verilog/SystemVerilog tests
- Runs both Verilog and UHDM frontends on each test
- Performs formal equivalence checking when both frontends succeed
- Reports UHDM-only successes (tests that only work with UHDM frontend)
- Creates test results in `test/run/` directory structure

### Current Test Cases
- **simple_counter** - 8-bit counter with async reset (tests increment logic, reset handling)
- **flipflop** - D flip-flop (tests basic sequential logic)
- **counter** - More complex counter design
- **simple_struct** - Packed struct handling and member access (tests struct bit slicing)
- **simple_assign** - Basic continuous assignments
- **simple_always_ff** - Sequential always_ff blocks with clock and reset
- **simple_always_ifelse** - Always blocks with if-else conditional logic
- **simple_hierarchy** - Module instantiation and port connections
- **simple_interface** - Interface-based connections
- **simple_memory** - Memory arrays and access patterns
- **simple_memory_noreset** - Memory array without reset signal
- **param_test** - Parameter passing and overrides
- **generate_test** - Generate for loops and if-else generate blocks with proper instance naming
- **simple_fsm** - Finite state machine with parameterized states (tests parameter references in case statements)
- **simple_instance_array** - Primitive gate arrays (tests and, or, xor, nand, not gates with array instances) *(UHDM-only)*
- **simple_package** - SystemVerilog packages with parameters, structs, and imports *(UHDM-only)*
- **struct_array** - Arrays of packed structs with complex indexing and member access
- **vector_index** - Bit-select assignments on vectors (tests `assign wire[bit] = value` syntax)
- **unique_case** - Unique case statements with for loops and break statements *(UHDM-only)*
- **nested_struct** - Nested structs from different packages with complex field access *(UHDM-only)*
- **nested_struct_nopack** - Nested structs without packages (tests synchronous if-else with switch statement generation)
- **simple_nested_struct_nopack** - Simpler nested struct test without packages
- **latchp** - Positive level-sensitive latch (tests latch inference from combinational always blocks)
- **latchn** - Negative level-sensitive latch (tests inverted enable condition handling)
- **latchsr** - Latch with set/reset functionality (tests nested if-else in combinational context)
- **adffs** - Async D flip-flop with set (from Yosys test suite)
- **add_sub** - Adder/subtractor with carry (from Yosys test suite)
- **logic_ops** - Logical operations with bit ordering (from Yosys test suite)
- **ndffnr** - Negative edge flip-flop with reset (from Yosys test suite)

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

**Current Status:**
```
# Tests that currently fail:
# (none - all tests pass!)
```

✅ **All 30 tests are passing!** The UHDM frontend achieves 100% success rate.

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
│   ├── memory.cpp              # Memory and array support
│   ├── memory_analysis.cpp     # Memory pattern detection
│   ├── clocking.cpp            # Clock domain analysis
│   ├── package.cpp             # Package support
│   ├── primitives.cpp          # Primitive gates
│   ├── ref_module.cpp          # Module references
│   ├── interface.cpp           # Interface declarations and modports
│   └── uhdm2rtlil.h           # Header with class definitions
├── test/                        # Test framework
│   ├── run_all_tests.sh        # Test runner script
│   ├── test_uhdm_workflow.sh   # Individual test workflow
│   ├── test_equivalence.sh     # Formal equivalence checking script
│   ├── failing_tests.txt       # Known failing tests list
│   └── */                      # Individual test cases
├── third_party/                # External dependencies
│   ├── Surelog/               # SystemVerilog parser (includes UHDM)
│   └── yosys/                 # Synthesis framework
├── .github/workflows/         # CI/CD configuration
├── build/                     # Build artifacts
├── CMakeLists.txt            # CMake build configuration
└── Makefile                   # Top-level build orchestration
```

## Test Results

The UHDM frontend test suite includes **30 test cases**:
- **4 UHDM-only tests** - Demonstrate superior SystemVerilog support (simple_instance_array, simple_package, unique_case, nested_struct)
- **26 Perfect matches** - Tests validated by formal equivalence checking between UHDM and Verilog frontends
- **0 Known failing tests** - All tests pass!

## Recent Improvements

### Latch Inference Support
- Added proper detection of combinational always blocks (`always @*`)
- Combinational blocks are now routed to dedicated combinational import path
- Added support for if_else statements in combinational contexts (distinct from if_stmt)
- Implemented proper type casting using `any_cast` based on `VpiType()`
- Support for arbitrarily nested if/if_else/case statements in combinational logic
- Temp wire initialization for proper latch inference
- Three new latch tests added (latchp, latchn, latchsr) demonstrating various latch patterns

### Interface Expansion Support
- Added automatic expansion of SystemVerilog interfaces to individual signals
- Interface instances are replaced with their constituent nets during RTLIL import
- Interface connections are properly mapped to individual signal connections
- Interface signal wires are converted to proper input/output ports
- Supports parameterized interfaces with different widths

### Parameter Reference Support
- Added proper handling of parameter references in expressions (e.g., in case statements)
- Parameters are now correctly resolved to their constant values instead of being treated as wire references
- Supports binary constant format "BIN:xx" used by UHDM for proper bit width handling

### Key Improvements
- **simple_interface** - Added interface expansion support, converting interface instances to individual signals
- **simple_fsm** - Fixed parameter reference handling in case statements, ensuring proper constant resolution
- **simple_memory** - Fixed async reset handling with proper temp wire usage in processes
- **simple_instance_array** - Added support for primitive gate arrays (and, or, xor, nand, not gates with array syntax)
- **simple_package** - Added full package support including imports, parameters, and struct types
- **struct_array** - Now passes with improved expression handling and struct support
- **generate_test** - Fixed by adding `proc` before `opt` in test workflow to handle multiple generated processes correctly
- **nested_struct_nopack** - Fixed synchronous if-else handling to generate proper switch statements matching Verilog frontend output

### Formal Equivalence Checking
The test framework now includes formal equivalence checking using Yosys's built-in equivalence checking capabilities:
- Uses `equiv_make`, `equiv_simple`, and `equiv_induct` to verify functional equivalence
- Validates that UHDM and Verilog frontends produce functionally equivalent netlists
- Works even when gate counts differ, as optimization strategies may vary
- Generates `test_equiv.ys` scripts in each test directory for debugging

### Primitive Gate Support
The UHDM frontend now supports Verilog primitive gates and gate arrays:
- Supported gates: `and`, `or`, `xor`, `nand`, `nor`, `xnor`, `not`, `buf`
- Array instantiation: `and gate_array[3:0] (out, in1, in2);`
- Proper bit-slicing for vectored connections
- Maps to Yosys internal gate cells (`$_AND_`, `$_OR_`, etc.)

### Package Support
The UHDM frontend now supports SystemVerilog packages:
- Package imports with `import package::*` syntax
- Package parameters and constants
- Package struct types with correct width calculation
- Cross-module type references from packages
- Proper wire context resolution during module instantiation

### UHDM Elaboration
The UHDM frontend now handles elaboration automatically:
- The plugin checks if the UHDM design is already elaborated using `vpi_get(vpiElaborated)` 
- If not elaborated, it performs elaboration using UHDM's ElaboratorListener
- This removes the need for the `-elabuhdm` flag in Surelog
- Elaboration happens transparently when reading UHDM files in Yosys

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

GitHub Actions automatically:
- Builds all components (Surelog, Yosys, UHDM Frontend)
- Runs comprehensive test suite
- Uploads test results and build artifacts
- Provides clear pass/fail status

See `.github/workflows/ci.yml` for configuration details.

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