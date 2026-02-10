# UHDM to RTLIL Frontend

![CI](https://github.com/username/uhdm2rtlil/workflows/CI/badge.svg)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language).

## Overview

This project bridges the gap between SystemVerilog source code and Yosys synthesis by leveraging two key components:

1. **Surelog** - Parses SystemVerilog and generates UHDM
2. **UHDM Frontend** - Converts UHDM to Yosys RTLIL

This enables full SystemVerilog synthesis capability in Yosys, including advanced features not available in Yosys's built-in Verilog frontend.

### Test Suite Status
- **Total Tests**: 107 tests covering comprehensive SystemVerilog features
- **Success Rate**: 97% (104/107 tests functional)
- **Perfect Matches**: 99 tests with identical RTLIL output between UHDM and Verilog frontends
- **UHDM-Only Success**: 5 tests demonstrating UHDM's superior SystemVerilog support:
  - `custom_map_incomp` - Custom mapping features
  - `nested_struct` - Complex nested structures
  - `simple_instance_array` - Instance array support
  - `simple_package` - Package support
  - `unique_case` - Unique case statement support
- **Known Failures**: 3 tests with issues:
  - `case_expr_const` - Equivalence check failure (expected)
  - `forloops` - Equivalence check failure (expected)
  - `mem2reg_test1` - Equivalence check failure
- **Recent Fixes**:
  - `genblk_order` - Fixed nested generate blocks with same name ✅
    - Reordered generate scope import to process nested scopes before continuous assignments
    - Added proper Actual_group() checking in hier_path for correct signal resolution
    - Handles generate block name shadowing correctly
  - `genvar_loop_decl_1` - Fixed generate scope wire initialization with hierarchical name lookup ✅
  - `genvar_loop_decl_2` - Fixed with Surelog update for proper hierarchical path assignment handling ✅
  - `carryadd` - Now passing with fixed carry addition handling ✅
  - `simple_enum` - Now passing with proper enum value handling ✅
  - `forgen01` - Fixed nested for loops in initial blocks using interpreter ✅
    - Added support for both ref_obj and ref_var in assignment statements
    - Generalized interpreter usage for any complex initialization patterns
    - Dynamic array detection and size determination
  - `asym_ram_sdp_read_wider` - Fixed array_net memory detection and dynamic indexing ✅
  - Improved shift register detection to run before array_net processing ✅
  - Fixed traversal depth in `has_only_constant_array_accesses` for proper dynamic access detection ✅
  - Added support for vpiIf statement type in array access checking ✅
  - **Function Support** - Significantly improved ✅
    - Function calls in continuous assignments now fully working
    - Proper parameter mapping from function arguments to actual signals
    - Function bodies converted to RTLIL processes with correct wire naming
    - Support for functions with if/else, case statements, and expressions
    - Added support for integer variables in functions (32-bit signed)
    - Fixed loop variable detection for ref_var types enabling loop unrolling
    - Removed hardcoded "result" assumptions - functions can assign to any variable
    - Fixed parameter vs variable detection in function return value scanning
    - Added support for named_begin blocks in functions
    - **Functions with output parameters now fully supported** ✅
      - Proper distinction between input/output parameters (VpiDirection)
      - Nested function calls with parameter passing working correctly
      - Fixed integer parameter width detection (32-bit for integer types)
      - Removed superfluous X assignments for input parameters
    - `code_tidbits_fsm_using_function` now passes equivalence check
    - `simple_function` test added and passing
    - **Recursive function support with constant propagation** ✅
      - Implemented call stack architecture for tracking recursive function contexts
      - Added constant propagation through function parameters
      - Automatic compile-time evaluation of recursive functions with constant inputs
      - `fib` and `fib_simple` tests now passing with efficient RTLIL generation
      - Reduced RTLIL size by 93% through constant propagation optimization
    - New function tests added: `function_arith`, `function_bool`, `function_case`, `function_nested` (all passing)
    - `function_loop`, `function_mixed`, `many_functions` - Fixed and now passing all tests
    - `function_output` - Functions with output parameters and nested calls now passing ✅
  - **Processing Order and autoidx Consistency** ✅
    - Fixed processing order: continuous assignments now processed before always blocks
    - Consistent use of Yosys global autoidx counter for unique naming
    - Removed duplicate autoidx increments in intermediate wire creation
    - Better alignment with Verilog frontend naming conventions
  - Added consistent cell naming with source location tracking for all cell types ✅
    - Created `generate_cell_name()` helper function for standardized naming
    - Applied to all arithmetic, logical, comparison, and reduction operations
    - Improves debugging with source file and line number in cell names

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
  - System function calls ($signed, $unsigned)
  - User-defined function calls with good support (simple functions, arithmetic, boolean logic, case statements, nested if-else)
  - Struct member access (e.g., `bus.field`)
  - Hierarchical signal references
  - Parameter references with HEX/BIN/DEC formats
  - Loop variable substitution in generate blocks
- **Control Flow**: If-else statements, case statements (including constant evaluation in initial blocks), for loops with compile-time unrolling and variable substitution, named begin blocks
- **Memory**: Array inference, memory initialization, for-loop memory initialization patterns, asymmetric port RAM with different read/write widths
- **Shift Registers**: Automatic detection and optimization of shift register patterns (e.g., `M[i+1] <= M[i]`)
- **Generate Blocks**: 
  - For loops with proper scope handling
  - If-else generate conditions
  - Hierarchical naming (e.g., `gen_loop[0].signal`)
  - Net and variable imports from generate scopes
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

### Current Test Cases (91 total - 88 passing, 3 known issues)
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
- **adff** - Async D flip-flop with async reset (from Yosys test suite)
- **adffn** - Async D flip-flop with negative-edge async reset (from Yosys test suite)
- **adffs** - Async D flip-flop with set (from Yosys test suite)
- **dffs** - D flip-flop with synchronous preset (from Yosys test suite)
- **add_sub** - Adder/subtractor with carry (from Yosys test suite)
- **logic_ops** - Logical operations with bit ordering (from Yosys test suite)
- **ndffnr** - Negative edge flip-flop with reset (from Yosys test suite)
- **blockrom** - Memory initialization using for loops with LFSR pattern (tests loop unrolling and constant evaluation)
- **mul** - Multiplication with correct result width calculation (tests arithmetic operation width inference)
- **mul_plain** - Simple combinational multiplier from Gatemate test suite
- **mul_signed_async** - Signed multiplier with async reset and pipeline registers from Gatemate test suite
- **mul_unsigned_sync** - Unsigned multiplier with sync reset and pipeline registers from Gatemate test suite
- **mux2** - 2-to-1 multiplexer using conditional operator (tests ternary expression)
- **mux4** - 4-to-1 multiplexer using case statement (tests case statement with bit selection)
- **mux8** - 8-to-1 multiplexer using nested conditional operators (tests complex ternary chains)
- **mux16** - 16-to-1 multiplexer using dynamic bit selection (tests non-constant indexed access)
- **macc** - Multiply-accumulate unit from Xilinx (tests power operator, large constants, process structures)
- **code_hdl_models_decoder_2to4_gates** - 2-to-4 decoder using primitive gates (tests gate instantiation and connections)
- **unbased_unsized** - SystemVerilog unbased unsized literals ('0, '1, 'x, 'z), cast operations, and full assertion support (✅ PASSING)

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
- 105 of 110 tests are passing or working as expected
- 5 tests are in the failing_tests.txt file (expected failures)

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

The UHDM frontend test suite includes **110 test cases**:
- **5 UHDM-only tests** - Demonstrate superior SystemVerilog support (custom_map_incomp, nested_struct, simple_instance_array, simple_package, unique_case)
- **100 Perfect matches** - Tests validated by formal equivalence checking between UHDM and Verilog frontends
- **105 tests passing** - with 5 known failures documented in failing_tests.txt

## Recent Improvements

### Recursive Expression Import and Operation Support
- Refactored expression import to use proper recursive approach for nested expressions
- Fixed handling of concatenation operations (vpiConcatOp) within other expressions
- Added support for unary minus operation (vpiMinusOp) for expressions like `-$signed({1'b0, a})`
- Added support for shift operations (vpiLShiftOp, vpiRShiftOp) for `<<` and `>>` operators
- Concatenation operations inside system function calls now properly import their operands
- Expression evaluation now correctly handles arbitrary nesting depth
- Fixed wreduce tests by properly handling complex nested expressions

### System Function Call Improvements
- Enhanced $signed and $unsigned system function handling
- System function arguments are now properly evaluated recursively
- Added debug logging for tracking empty operands in system functions
- Fixed issue where concat operations inside $signed were returning empty signals

### Primitive Gate Enhancements
- Fixed handling of Verilog primitives with multiple outputs (buf, not)
- Primitives with multiple outputs now create separate cells for each output
- Proper connection mapping for multi-output primitives
- Fixed verilog_primitives test with correct multi-output handling

### Process and Case Statement Improvements
- Enhanced constant case evaluation in initial blocks
- Added support for evaluating case statements with constant conditions
- Improved handling of integer variables in procedural loops
- Fixed forloops test by properly handling integer variable assignments

### Unbased Unsized Literal and Assertion Support
- Added proper handling for SystemVerilog unbased unsized literals ('0, '1, 'x, 'z)
- Implemented cast operation support (vpiCastOp) for expressions like 3'('x)
- Fixed UInt constant parsing to use stoull for large values (e.g., 0xFFFFFFFFFFFFFFFF)
- Added extract_const_from_value helper function with STRING value support
- Fixed single-bit constant extension to properly replicate X/Z values across width
- Added basic support for immediate assertions (vpiImmediateAssert) to prevent crashes
- Assertions are currently skipped during import (future enhancement: convert to $assert cells)

### Memory Write Restructuring for Complex Loop-based Writes
- Fixed asym_ram_sdp_write_wider test by restructuring memory write generation
- Implemented proper for-loop unrolling with variable substitution in memory addresses and data slices
- Added support for indexed part select with loop variable substitution (e.g., `diA[(i+1)*minWIDTH-1 -: minWIDTH]`)
- Memory writes in loops now generate proper `$memwr$` temporary wires matching Verilog frontend structure
- Added priority values to memwr statements for correct write ordering
- Eliminated external combinational cells in favor of process-internal switch statements
- All 53 tests now pass with no known failures

### Process Structure Improvements for always_ff Blocks
- Fixed process structure generation to use switch statements inside process bodies instead of external mux cells
- Added proper handling of simple if statements without else branches in synchronous contexts
- Correctly distinguishes between `vpiIf` (type 22) and `vpiIfElse` (type 23) for proper type casting
- Fixed type casting: `vpiIf` statements cast to `UHDM::if_stmt*`, `vpiIfElse` to `UHDM::if_else*`
- Eliminated redundant assignments in default case for simple if without else
- Process structures now match Verilog frontend output exactly for better optimization

### Net Declaration Assignment Improvements
- Fixed PROC_INIT pass failures by checking if RHS expressions are constant
- Constant expressions create init processes (as before)
- Non-constant expressions (e.g., `wire [8:0] Emp = ~(Blk | Wht)`) create continuous assignments
- Prevents "Failed to get a constant init value" errors during synthesis

### Expression and Arithmetic Improvements
- Added support for power operator (`**`) used in expressions like `2**(SIZEOUT-1)`
- Fixed integer parsing to use `std::stoll` for large constants (e.g., 549755813888)
- Corrected Mux (conditional operator) argument ordering: `Mux(false_val, true_val, cond)`
- Fixed Add and Sub operations to create proper arithmetic cells using `addAdd`/`addSub`
- All arithmetic operations now generate appropriate cells instead of just wires

### Latch Inference Support
- Added proper detection of combinational always blocks (`always @*`)
- Combinational blocks are now routed to dedicated combinational import path
- Added support for if_else statements in combinational contexts (distinct from if_stmt)
- Implemented proper type casting using `any_cast` based on `VpiType()`
- Support for arbitrarily nested if/if_else/case statements in combinational logic
- Temp wire initialization for proper latch inference
- Three new latch tests added (latchp, latchn, latchsr) demonstrating various latch patterns

### For Loop Unrolling Support
- Added support for unrolling for loops in initial blocks for memory initialization
- Implemented compile-time expression evaluation with variable substitution
- Generates $meminit_v2 cells for memory initialization patterns
- Extracts loop bounds and parameters from UHDM elaborated model
- Handles complex LFSR-style pseudo-random number generation patterns
- Supports nested expressions including multiplication, shifts, and XOR operations
- Properly handles SystemVerilog integer (32-bit) vs 64-bit constant semantics
- Added blockrom test demonstrating loop-based memory initialization

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

### Dynamic Bit Selection Support
- Implemented non-constant indexed access (e.g., `D[S]` where S is a signal)
- Creates $shiftx cells for dynamic bit selection operations
- Enables support for multiplexers and other dynamic indexing patterns
- Added mux16 test demonstrating 16-to-1 multiplexer functionality

### Signed Attribute Support
- Added proper detection of signed ports and nets from UHDM typespecs
- Implemented signed attribute handling for arithmetic operations
- Signed types (int, byte, short_int, long_int) are properly marked as signed
- Logic types with VpiSigned attribute are correctly handled
- Enables correct signed multiplication and other arithmetic operations

### Memory Write Handling in Synchronous Processes
- Implemented proper architectural fix for memory writes in `always_ff` blocks
- Memory writes (`mem[addr] <= data`) are no longer placed directly in sync rules
- Instead, creates temporary wires for memory control signals (address, data, enable)
- Imports statements into process body (`root_case`) with assignments to temp wires
- Creates single `mem_write_action` in sync rule using the temp wires
- This matches Yosys's expected process model and prevents PROC_MEMWR pass failures
- Added helper functions `is_memory_write()` and `scan_for_memory_writes()` to detect memory operations
- Verified with Xilinx memory tests: priority_memory, sp_write_first, sp_read_first, sp_read_or_write

### Key Improvements
- **simple_interface** - Added interface expansion support, converting interface instances to individual signals
- **simple_fsm** - Fixed parameter reference handling in case statements, ensuring proper constant resolution
- **simple_memory** - Fixed async reset handling with proper temp wire usage in processes
- **simple_instance_array** - Added support for primitive gate arrays (and, or, xor, nand, not gates with array syntax)
- **simple_package** - Added full package support including imports, parameters, and struct types
- **struct_array** - Now passes with improved expression handling and struct support
- **generate_test** - Fixed by adding `proc` before `opt` in test workflow to handle multiple generated processes correctly
- **nested_struct_nopack** - Fixed synchronous if-else handling to generate proper switch statements matching Verilog frontend output
- **mux4** - Fixed case statement width matching to ensure case values have the same width as the switch signal
- **mul** - Fixed multiplication result width calculation to match Verilog frontend (sum of operand widths)
- **macc** - Fixed power operator support, large constant parsing, Mux ordering, arithmetic cell creation, and process structures
- **vector_index** - Fixed net declaration assignments with non-constant expressions to use continuous assignments
- **priority_memory**, **sp_write_first**, **sp_read_first**, **sp_read_or_write** - Fixed with proper memory write handling architecture

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
- Fixed import_primitives() function to properly iterate through module->Primitives()
- Added code_hdl_models_decoder_2to4_gates test demonstrating gate usage

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