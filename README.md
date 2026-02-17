# UHDM to RTLIL Frontend

![CI](https://github.com/username/uhdm2rtlil/workflows/CI/badge.svg)

A Yosys frontend that enables SystemVerilog synthesis through UHDM (Universal Hardware Data Model) by converting UHDM representations to Yosys RTLIL (Register Transfer Level Intermediate Language).

## Overview

This project bridges the gap between SystemVerilog source code and Yosys synthesis by leveraging two key components:

1. **Surelog** - Parses SystemVerilog and generates UHDM
2. **UHDM Frontend** - Converts UHDM to Yosys RTLIL

This enables full SystemVerilog synthesis capability in Yosys, including advanced features not available in Yosys's built-in Verilog frontend.

### Test Suite Status
- **Total Tests**: 114 tests covering comprehensive SystemVerilog features
- **Success Rate**: 98% (112/114 tests functional)
- **Perfect Matches**: 107 tests with identical RTLIL output between UHDM and Verilog frontends
- **UHDM-Only Success**: 5 tests demonstrating UHDM's superior SystemVerilog support:
  - `custom_map_incomp` - Custom mapping features
  - `nested_struct` - Complex nested structures
  - `simple_instance_array` - Instance array support
  - `simple_package` - Package support
  - `unique_case` - Unique case statement support
- **Known Failures**: 2 tests with issues:
  - `forloops` - Equivalence check failure (expected)
  - `multiplier` - SAT proves primary outputs equivalent, but equiv_make fails due to internal FullAdder instance naming differences (UHDM: `unit_0..N` vs Verilog: `\addbit[0].unit`)
- **Recent Additions**:
  - `func_tern_hint` - Recursive functions with ternary type/width hints in self-determined context
- **Recent Fixes**:
  - `struct_access` - Packed struct field access with complex initial blocks ✅
    - Fixed memory analyzer crash on initial blocks (skip vpiInitial in memory analysis)
    - Fixed vpiIf/vpiIfElse type casting in memory_analysis.cpp (vpiIf→if_stmt, vpiIfElse→if_else)
    - Added ReduceBool for multi-bit conditions in mux select and switch/compare operations
    - Implemented combinational import strategy for initial blocks with complex control flow (case/if)
    - Added local variable handling in unnamed begin blocks
    - Split `import_initial` into sync (simple assignments, for loops) and comb (case/if) strategies
  - `multiplier` - 4x4 2D array multiplier with parameterized RippleCarryAdder and FullAdder ✅
    - Implemented `vpiMultiConcatOp` (replication operator `{N{expr}}`)
    - Implemented `vpiVarSelect` for 2D array part selects (e.g., `PP[i-1][M+i-1:0]`)
    - Added expression context width propagation for Verilog context-determined sizing
    - Fixed parameter resolution in elaborated modules to use actual values over base defaults
  - `const_func` - Constant functions in generate blocks with string parameters ✅
    - Added `vpiStringConst` support for string parameter constants
    - Added `$floor`/`$ceil` system function handling
    - Added `vpiBitNegOp` to compile-time and interpreter evaluation
    - Extended for loop unrolling for `vpiNeqOp` conditions and `vpiFuncCall` bounds
    - Deduplicated initial block assignments with generate-scope priority
    - Added parameter fallback for part selects (e.g., `OUTPUT[15:8]`)
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
  - **Task Inlining in Always Blocks** ✅
    - Task calls in combinational always blocks are now inlined with proper parameter mapping
    - Supports input/output parameters and local variables within tasks
    - Named begin blocks inside tasks create hierarchical wires with correct scoping
    - `current_comb_values` tracking ensures task bodies read correct in-progress signal values
    - Variable shadowing in nested scopes handled via save/restore pattern on task_mapping
    - `scope_task` test now passing formal equivalence check
  - **Function Inlining in Combinational Always Blocks** ✅
    - Function calls with variable arguments in always @* blocks are now inlined into the calling process
    - Eliminates combinational feedback loops caused by separate RTLIL processes for function calls
    - Named begin blocks within functions properly track intermediate values via `comb_value_aliases`
    - Cell chaining through `current_comb_values` ensures RHS expressions read from cell outputs, not wires
    - Save/restore pattern on `current_comb_values` for correct variable scoping in named begin blocks
    - `scopes` test now passing formal equivalence check (functions + tasks + nested blocks with variable shadowing)
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
  - Packed structures with member access via bit slicing
  - Struct arrays with complex indexing
  - Package types and imports
- **Procedural Blocks**: 
  - `always_ff` - Sequential logic with proper clock/reset inference
  - `always_comb` - Combinational logic
  - `always` - Mixed sequential/combinational logic
- **Expressions**: 
  - Arithmetic, logical, bitwise, comparison, ternary operators
  - System function calls ($signed, $unsigned, $floor, $ceil)
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

### Current Test Cases (114 total - 112 passing, 2 known issues)

#### Sequential Logic - Flip-Flops & Registers
- **flipflop** - D flip-flop (tests basic sequential logic)
- **dff_styles** - Simple D flip-flop with synchronous clock edge
- **dff_different_styles** - Multiple DFF variants with different reset styles and polarities
- **dffsr** - D flip-flop with async set/reset
- **adff** - Async D flip-flop with async reset (from Yosys test suite)
- **adffn** - Async D flip-flop with negative-edge async reset (from Yosys test suite)
- **dffs** - D flip-flop with synchronous preset (from Yosys test suite)
- **ndffnr** - Negative edge flip-flop with reset (from Yosys test suite)
- **latchp** - Positive level-sensitive latch (tests latch inference from combinational always blocks)
- **latchn** - Negative level-sensitive latch (tests inverted enable condition handling)
- **latchsr** - Latch with set/reset functionality (tests nested if-else in combinational context)

#### Counters & Sequential Designs
- **simple_counter** - 8-bit counter with async reset (tests increment logic, reset handling)
- **counter** - More complex counter design
- **always01** - 4-bit synchronous counter with mux-based async reset
- **always02** - 4-bit counter with synchronous reset in nested block
- **always03** - Mixed blocking and non-blocking assignments with if-else chains
- **simple_always_ff** - Sequential always_ff blocks with clock and reset
- **simple_always_ifelse** - Always blocks with if-else conditional logic

#### Combinational Logic - Boolean & Arithmetic
- **lut_map_and** - Simple AND gate (tests basic 2-input logic)
- **lut_map_or** - Simple OR gate (tests basic 2-input logic)
- **lut_map_xor** - Simple XOR gate (tests basic 2-input logic)
- **lut_map_not** - Simple NOT gate (tests unary operators)
- **lut_map_mux** - 2-to-1 multiplexer with ternary operator
- **lut_map_cmp** - Multiple comparison operators (<=, <, >=, >, ==, !=) with constants
- **logic_ops** - Logical operations with bit ordering (from Yosys test suite)
- **opt_share_add_sub** - Shared add/subtract using ternary selection (tests operator sharing)
- **simple_assign** - Basic continuous assignments
- **partsel_simple** - Part selection with dynamic offset using +: and -: operators
- **wreduce_test0** - Signed arithmetic with width reduction
- **wreduce_test1** - Arithmetic operations with output width reduction
- **unbased_unsized** - SystemVerilog unbased unsized literals ('0, '1, 'x, 'z) and cast operations

#### Multiplexers
- **mux2** - 2-to-1 multiplexer using conditional operator (tests ternary expression)
- **mux4** - 4-to-1 multiplexer using case statement (tests case statement with bit selection)
- **mux8** - 8-to-1 multiplexer using nested conditional operators (tests complex ternary chains)
- **mux16** - 16-to-1 multiplexer using dynamic bit selection (tests non-constant indexed access)

#### Multipliers & Arithmetic Pipelines
- **mul** - Multiplication with correct result width calculation (tests arithmetic width inference)
- **mul_plain** - Simple combinational multiplier from Gatemate test suite
- **mul_signed_async** - Signed multiplier with async reset and pipeline registers
- **mul_unsigned** - 16x24-bit multiplier with 3-stage pipelined result
- **mul_unsigned_sync** - Unsigned multiplier with sync reset and pipeline registers
- **mul_unsigned_sync_simple** - 6x3-bit synchronous multiplier with clock enable
- **mul_sync_enable_test** - 6x3-bit multiplier with synchronous reset and enable
- **mul_sync_reset_test** - 6x3-bit multiplier with synchronous reset
- **macc** - Multiply-accumulate unit from Xilinx (tests power operator, large constants, process structures)

#### State Machines
- **simple_fsm** - Finite state machine with parameterized states (tests parameter references in case statements)
- **fsm** - 3-state finite state machine with grant signals
- **code_tidbits_fsm_using_function** - FSM implemented with combinational function (tests function-based state logic)
- **power_state** - Output logic decoder for state machine
- **simple_enum** - Enum-based state machine with assertions
- **unique_case** - Unique case statements with for loops and break statements *(UHDM-only)*

#### Functions
- **simple_function** - AND-OR tree function driving flip-flop (tests function in continuous assignment)
- **function_arith** - Arithmetic function with add/subtract/shift/AND/XOR
- **function_bool** - Boolean logic function with if-else modes
- **function_case** - Case statement function with shift operations
- **function_loop** - Loop-based bit reversal function
- **function_nested** - Nested if-else maximum finder
- **function_mixed** - Mixed arithmetic, bit manipulation, and conditional modes
- **function_output** - Function with output parameter assignments
- **many_functions** - Multiple function types: arithmetic, boolean, case, nested, loop, mixed
- **fib** - Recursive Fibonacci with wrapper function and output parameters
- **fib_simple** - Fibonacci with wrapper function output assignments
- **fib_recursion** - Direct recursive Fibonacci in initial block
- **fib_initial** - Initial block with function call evaluation
- **func_tern_hint** - Recursive functions with ternary type/width hints and self-determined context

#### Scope & Variable Shadowing
- **scope_func** - Function calls with variable inputs in always blocks (tests function scope resolution)
- **scopes** - Functions, tasks, and nested blocks with variable shadowing (tests complex scoping)
- **scope_task** - Tasks with nested named blocks and local variables (tests task inlining in always blocks)

#### Arrays & Memory
- **arrays01** - 4-bit x16 array with synchronous read and write (tests memory inference)
- **simple_memory** - Memory arrays and access patterns
- **simple_memory_noreset** - Memory array without reset signal
- **blockrom** - Memory initialization using for loops with LFSR pattern (tests loop unrolling and constant evaluation)
- **priority_memory** - Priority-based memory access patterns
- **mem2reg_test1** - Combinational array with write and simultaneous read
- **mem2reg_test2** - Annotated 8-element array with loop-based writes and reads
- **asym_ram_sdp_read_wider** - Asymmetric RAM with read port 4x wider than write
- **asym_ram_sdp_write_wider** - Asymmetric RAM with write port 4x wider than read
- **sp_read_first** - Single port RAM with read-first semantics
- **sp_read_or_write** - Single port RAM with read-or-write semantics
- **sp_write_first** - Single port RAM with write-first semantics

#### Data Types & Structs
- **simple_struct** - Packed struct handling and member access (tests struct bit slicing)
- **struct_array** - Arrays of packed structs with complex indexing and member access
- **struct_access** - Packed struct field access with CHECK macros, case/if in initial blocks, and assertions
- **nested_struct** - Nested structs from different packages with complex field access *(UHDM-only)*
- **nested_struct_nopack** - Nested structs without packages (tests synchronous if-else with switch statements)
- **simple_nested_struct_nopack** - Simpler nested struct test without packages
- **enum_simple** - State machine with typedef enum and state transitions
- **enum_values** - Multiple enum types with custom values and attributes
- **typedef_simple** - Multiple typedef definitions with signed/unsigned types

#### Generate & Parameterization
- **param_test** - Parameter passing and overrides
- **generate_test** - Generate for loops and if-else generate blocks with proper instance naming
- **simple_generate** - Generate loop with AND gates clocked per-bit
- **forgen01** - Generate block with nested loops computing prime LUT
- **forgen02** - Generate block implementing parameterized ripple adder
- **gen_test1** - Nested generate loops with if-then conditional blocks
- **genblk_order** - Nested generate blocks with variable shadowing
- **genvar_loop_decl_1** - Generate loop with inline genvar declaration and width arrays
- **genvar_loop_decl_2** - Generate with genvar shadowing and hierarchical references
- **carryadd** - Generate-based carry adder with hierarchical references
- **multiplier** - 4x4 2D array multiplier with parameterized RippleCarryAdder and FullAdder using generate loops *(known equiv mismatch - SAT proves outputs equivalent)*
- **const_func** - Constant functions in generate blocks with string parameters, `$floor`, and bitwise negation
- **forloops** - For loops in both clocked and combinational always blocks *(known failure)*
- **case_expr_const** - Case statement with constant expressions

#### Module Hierarchy & Interfaces
- **simple_hierarchy** - Module instantiation and port connections
- **simple_interface** - Interface-based connections
- **simple_instance_array** - Primitive gate arrays (and, or, xor, nand, not with array instances) *(UHDM-only)*
- **simple_package** - SystemVerilog packages with parameters, structs, and imports *(UHDM-only)*
- **custom_map_incomp** - Custom technology mapping with incomplete instantiation *(UHDM-only)*

#### Primitives & Miscellaneous
- **verilog_primitives** - Instantiation of buf, not, and xnor primitives
- **escape_id** - Module and signal names with special characters and escapes
- **code_hdl_models_decoder_2to4_gates** - 2-to-4 decoder using primitive gates
- **code_hdl_models_parallel_crc** - 16-bit parallel CRC with combinational feedback logic
- **aes_kexp128** - AES key expansion circuit with XOR feedback and array registers
- **simple_abc9** - ABC9 test collection with blackbox, whitebox, and various port types
- **vector_index** - Bit-select assignments on vectors (tests `assign wire[bit] = value` syntax)

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
- 112 of 114 tests are passing or working as expected
- 2 tests are in the failing_tests.txt file (expected failures)

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

The UHDM frontend test suite includes **114 test cases**:
- **5 UHDM-only tests** - Demonstrate superior SystemVerilog support (custom_map_incomp, nested_struct, simple_instance_array, simple_package, unique_case)
- **107 Perfect matches** - Tests validated by formal equivalence checking between UHDM and Verilog frontends
- **112 tests passing** - with 2 known failures documented in failing_tests.txt

## Recent Improvements

### Initial Block Import Strategy
- Split `import_initial` into two strategies based on statement content analysis
- **Sync approach** (default): Handles simple assignments and for-loop unrolling using STa/STi sync rules
- **Comb approach**: Handles complex control flow (case/if/if_else) using switch rules and combinational processes
- `statement_contains_control_flow()` helper recursively checks for vpiIf/vpiIfElse/vpiCase in statement trees
- Prevents "Failed to get a constant init value" errors from mux cells in PROC_INIT
- Prevents incorrect `sync always` continuous driving that would override always_ff blocks

### Memory Analyzer Robustness
- Skip initial blocks (vpiInitial) in `analyze_memory_usage_in_processes` to avoid spurious memory detection
- Fixed vpiIf/vpiIfElse type casting in `analyze_statement_for_memory`: vpiIf uses `if_stmt*`, vpiIfElse uses `if_else*`
- Added proper vpiIfElse handling with both then-stmt and else-stmt traversal

### Multi-bit Condition Handling
- Added `ReduceBool` normalization for multi-bit conditions across all process import paths
- Fixes mux select width errors (64-bit conditions reduced to 1-bit for mux select)
- Fixes switch signal/compare size assertion failures in combinational context
- Applied consistently in: `import_if_stmt_sync`, `import_if_stmt_comb`, `import_if_else_comb`, and `import_statement_comb` (both Process and CaseRule overloads)

### Local Variables in Unnamed Begin Blocks
- Extended `import_begin_block_comb` to handle `vpiBegin` blocks (not just `vpiNamedBegin`) with Variables()
- Local variables in unnamed begin blocks are created as module wires with unique hierarchical names
- Added `unnamed_block_counter` for generating unique block names

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