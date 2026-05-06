# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Yosys frontend that converts SystemVerilog to RTLIL (Register Transfer Level Intermediate Language) via UHDM (Universal Hardware Data Model). The workflow is: SystemVerilog → Surelog → UHDM → UHDM Frontend → RTLIL → Yosys synthesis.

The Yosys submodule is pinned at **v0.64** (`third_party/yosys`).

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
cd test/<test_name> && ../../out/current/bin/yosys -m ../../build/uhdm2rtlil.so -p "read_uhdm -debug slpp_all/surelog.uhdm"

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
   - Enable with `-debug` flag: `read_uhdm -debug slpp_all/surelog.uhdm`
   - Adds extensive logging of UHDM traversal
   - Shows parameter resolution and expression evaluation

5. **AllModules vs TopModules (Elaborated Model)**:
   - Surelog provides two views: `AllModules` (flat definitions) and `TopModules` (elaborated hierarchy)
   - **AllModules types cannot be trusted** for signal attributes like signedness (`VpiSigned`), widths, and type information
   - Only the **Elaborated model** (from `TopModules`) contains the correct, fully-resolved signal types
   - When importing module definitions, always prefer data from the elaborated instances under `TopModules`
   - Example: A `wire signed` declared in SV may have `VpiSigned:1` on the elaborated `logic_net` but NOT on the AllModules version

6. **Port vs Net Typespec Inconsistency**:
   - In the elaborated model, a **port**'s typespec and the corresponding **net**'s typespec can point to **different** typespecs
   - Example: For `input reg8_t [0:3] in`, the port's `vpiTypedef` ref_typespec points to the full packed array `logic_typespec` (with `Elem_typespec` + Range `[0:3]`), but the net's `vpiTypespec` points to just `reg8_t` (the element type, 8-bit)
   - When both port and net information is needed (e.g., for packed array detection), store metadata as wire attributes during `import_port()` and read them back later in expression handling
   - The `Actual_group()` on a `bit_select` resolves to the net, not the port, so it inherits the net's (potentially incomplete) typespec

7. **Packed Multidimensional Array Typespec Variants**:
   - Surelog represents packed arrays in multiple ways depending on the SV source:
     - **Multi-range**: `logic [0:3][7:0]` → `logic_typespec` with `Ranges()->size() > 1`
     - **Elem_typespec**: `reg8_t [0:3]` → `logic_typespec` with `Elem_typespec()` pointing to element type and 1 Range
     - **Typedef alias**: `typedef reg8_t [0:3] reg2dim1_t` → `logic_typespec` with `Elem_typespec()` pointing to ANOTHER packed array typespec (which itself has `Elem_typespec`), and the Range is **redundant** (duplicated from the inner type)
   - For typedef aliases, detect nested `Elem_typespec` chains: if `Elem_typespec()->Actual_typespec()` is a `logic_typespec` that itself has `Elem_typespec`, the outer Range must NOT be multiplied again
   - `ExprEval::size()` returns only the outer dimension count for Elem_typespec variants (e.g., returns 4 for `reg8_t [0:3]` instead of 32), so manual `element_width * range_size` calculation is required

8. **UHDM Inheritance and Typespec Access**:
   - `bit_select` extends `ref_obj` which has `Actual_group()` → returns the underlying `logic_net` or `logic_var`
   - Both `logic_net` (via `net` → `nets` → `simple_expr` → `expr`) and `logic_var` (via `variables` → `simple_expr` → `expr`) inherit `Typespec()` from the `expr` base class
   - `logic_typespec::Elem_typespec()` returns a `ref_typespec*`, which must be followed via `Actual_typespec()` to get the actual element typespec
   - UHDM dump uses shared objects: a typespec's full details (Ranges, Elem_typespec) may only appear once in the dump even if referenced from multiple places

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
All 156 tests are currently passing (0 failures). `test/failing_tests.txt` is empty.

### Signedness Handling

- **Net signedness**: Check both `logic_typespec->VpiSigned()` AND `uhdm_net->VpiSigned()` directly (Surelog may set it on either)
- **Operation signedness**: Must propagate from operand wires to cell parameters (`A_SIGNED`/`B_SIGNED`) and output wires
- **Port sign extension**: Yosys hierarchy pass sign-extends based on `wire->is_signed` on the connected signal
- **Signed constants at ports**: Create a signed intermediate wire so the hierarchy pass knows to sign-extend
- **Process assignment sign extension**: `import_assignment_comb` must check `rhs.is_wire() && rhs.as_wire()->is_signed` and call `extend_u0(size, rhs_is_signed)` — applies to ALL three overloads of `import_assignment_comb` and to `import_assignment_sync`

### Generate Scope Variable Initialization

- In UHDM, `integer x = -1;` in a generate scope stores the initializer in `variables::Expr()` (`vpiExpr`), NOT as a statement inside the always block
- `import_gen_scope` must call `var->Expr()` and create `module->connect(wire, import_expression(init_expr))` to drive the wire with its initial constant value
- Without this, the wire is undriven (X) and any expression using it produces incorrect results

### Temp Wire Dedup Key in `import_always_comb`

- For full-wire assignments (non-part-select), the `dedup_key` must use the actual RTLIL wire name (e.g., `test_integer.a`) not the bare local variable name (e.g., `a`)
- Without this fix, two generate blocks with the same-named local variable (`a`) both try to create `$0\a`, causing "Temp wire already exists" error
- Fix: for non-part-select, get `first_chunk.wire->name.str()` from `lhs_spec.chunks()` and use that as the dedup key (same approach already used for part-selects)

### Constant Type Inference

- `VpiConstType()` can return 0 (undefined) while `VpiValue()` has the correct prefix (`UINT:`, `BIN:`, etc.)
- Added fallback type inference from value string prefix in `import_constant()` (`expression.cpp`)

### Surelog Const-Folded Function Results: Signed BIN Constants

- When Surelog evaluates a function call at compile time (elaboration), it may store the result as a `BIN` constant with `vpiSize` equal to the function return type width
- If the function body assigns a **signed parameter** to the return variable (e.g., `func1 = inp` where `inp` is `input reg signed inp`), Surelog stores the raw bit value without sign-extension (e.g., `BIN:1, vpiSize:2` instead of `BIN:11, vpiSize:2`)
- The constant's `vpiTypespec → ref_typespec → logic_typespec` will have `VpiSigned():true` even when the constant value string is shorter than `vpiSize`
- Fix in `import_constant()` (`expression.cpp`): for `vpiBinaryConst` with `size > const_val.size()`, check `uhdm_const->Typespec()->Actual_typespec()->VpiSigned()` and if true, use `extend_u0(size, true)` (sign-extend) instead of zero-extending
- Pattern: `input reg signed inp` → `VpiSigned:1` on the typespec of the resulting folded constant

### Fill Constants (`'0`, `'1`, `'x`, `'z`) — Unbased Unsized Literals

- UHDM: `VpiSize() == -1`, `VpiValue() == "BIN:1"` for the `'1` fill constant
- `import_constant()` returns a 1-bit `SigSpec(S1)` — must NOT be zero-extended at assignment sites
- Fix in `import_assignment_sync()` (`process.cpp`): detect fill-ones before importing RHS, then replicate `S1` to the full LHS width instead of calling `extend_u0()`
- Fix in `interpreter.cpp` `evaluate_expression`: return `-1LL` for `'1` fill constants so `RTLIL::Const(-1, width)` produces all-ones in `import_initial_interpreted`
- Pattern: check `c->VpiSize() == -1 && std::string(c->VpiValue()) == "BIN:1"` at the assignment site

### Parameterized Module Instance Naming in Generate Scopes

- When `import_instance` tries to find the RTLIL module name prefix in `VpiFullName()`, it FAILS for parameterized modules (e.g., `$paramod\RippleCarryAdder\N=...` vs path `work@Top.gen[0].adder.addbit[0].unit`)
- Fix: if the RTLIL prefix match fails, try `current_instance->VpiFullName()` as the prefix (always an ancestor of the child's path) → extracts `addbit[0].unit` correctly
- Last resort fallback: `get_current_gen_scope() + "." + VpiName()` for deeply nested cases

### Constant Folding in Generate Scopes

- `import_operation` only folds all-const operations when `!loop_values.empty() || getCurrentFunctionContext() != nullptr`
- Generate-scope parameters (e.g., loop variable `i` in `addPartialProduct[i]`) resolve to constants via `VpiValue()` on the `parameter` object, but they do NOT set `loop_values`
- Fix: also fold when `!gen_scope_stack.empty()` — needed for indexed part-selects like `PP[(i-1)*(i+2*M)/2 +: M+i]`

### Function-Local Localparam Resolution (`localparam A = 32 - 1` inside functions)

- For `localparam A = expr` inside a function, Surelog does NOT set `parameter->VpiValue()` or `parameter->Expr()`
- Instead, the value expression is stored in `parameter->VpiParent()` → `param_assign->Rhs()`
- Fix in `import_ref_obj` (expression.cpp): when `VpiValue()` is empty and `Expr()` is null, check `param->VpiParent()` for a `param_assign` (UhdmType = `uhdmparam_assign`), then evaluate `pa->Rhs()` via `import_expression`
- Added `#include <uhdm/param_assign.h>` to expression.cpp
- Part-select LHS handler in `process_stmt_to_case`: `func3[A:B] = inp[A:B]` — the `part_select` node's ranges are `ref_obj` → parameter, and this resolution path is now needed
- `scan_for_direct_return_assignment` intentionally does NOT detect `uhdmpart_select` LHS — leaving `has_return_assignment = false` so the result wire is zero-initialized before the part-select writes its bits (correct for partial assignments)

### Equivalence Checking: Dead Wire Circular Dependencies

- When UHDM and Verilog synthesize differently (e.g., `gB → PP[0]` vs `PP[0] → gB`), `equiv_make` creates circular equiv cells that `equiv_induct` cannot resolve
- Fix in `test_equivalence.sh`: add `opt -purge` before `design -stash` for both gold and gate — removes dead wires (unused signals) that cause the circular dependency

### Equivalence Checking: Public-Typed Built-In Gates After write_verilog Round-Trip (Yosys 0.64+)

- `synth -auto-top; write_verilog -noexpr` escapes built-in gate cell types to public Verilog identifiers (`\$_MUX_`, `\$_AND_`, …); reading the synth output back creates cells of *public* type
- Yosys 0.64's `equiv_induct` aborts with "No SAT model available for cell …" because satgen only models the internal `$_MUX_`/`$_AND_`/etc. (in v0.62 this was just a warning, so the test passed despite some unmodelled cells)
- Yosys 0.64's abc default mapping prefers `$_MUX_` heavily where v0.62 used `$_ANDNOT_`/`$_ORNOT_`, so this hits any synth output containing muxes (e.g. the `rotate` test)
- Fix in `test_equivalence.sh`: after `equiv_make` (which pairs gold/gate by structure while they still reference the simcells library stubs from `read_verilog -lib +/simcells.v`), run `chtype -map \$_AND_ $_AND_` (and friends — `NAND`, `OR`, `NOR`, `XOR`, `XNOR`, `NOT`, `ANDNOT`, `ORNOT`, `MUX`, `NMUX`) to convert the public-typed cells back to their internal counterparts so satgen has SAT models for `equiv_simple` and `equiv_induct`

### Typed Net Declarations (`wand integer`, `wor typename`, etc.)

- Surelog bug: `compileNetDeclaration` overwrites the net keyword (e.g., `paNetType_Wand`) with the data type (e.g., `paIntegerAtomType_Integer`) in `m_type`, losing the original net type
- Fix: Added `m_subNetType` field to `Signal.h` to preserve the original net keyword separately
- `CompileHelper.cpp` `compileNetDeclaration`: calls `sig->setSubNetType(subnettype)` when `subnettype != slNoType` after creating the Signal
- `NetlistElaboration.cpp` `elabSignal`: reads `netKeyword = sig->getSubNetType()`, forces `isNet=true` when set, and uses `netKeyword` for all `getVpiNetType()` calls
- `ElaborationStep.cpp` `bindPortType_`: for typedef-named logics, calls `sig->setType(paIntVec_TypeLogic)` which OVERWRITES `m_type` — that's why `m_subNetType` as a separate field is essential
- `module.cpp` `import_net`: added `wiretype` attribute for `logic_typespec` with non-empty `VpiName` (handles typedef'd logic nets like `wire`/`wand`/`wor` with a typename)
- Result: `wand integer` and `wand typename` correctly appear as `logic_net` with `VpiNetType=vpiWand=2` in TopModules

### Always FF RTLIL Process Structure (`import_always_ff`)

- **Goal**: `import_always_ff` must produce a proper RTLIL process with `switch`/`case` structure inside the body (matching the Verilog frontend), NOT mux cells outside the process
- **Old approach** (wrong): `import_statement_sync` → `pending_sync_assignments` → flat mux-cell chains; produced 109 gates vs Verilog's 83 for a simple FSM
- **New approach** (correct): same `$0\temp-wire` + `import_statement_comb` pattern as `import_always_comb`, but with a posedge sync rule instead of STa
- **Non-blocking semantics**: `in_always_ff_body_mode = true` flag suppresses `current_comb_values` reads/writes during body processing; ensures all RHS expressions see original register values (not updated `$0\` values), matching SystemVerilog's non-blocking assignment semantics
  - Guards in `emit_comb_assign`: skip `current_comb_values[signal] = rhs` when flag is set
  - Guards in `import_assignment_comb`: skip passing `&current_comb_values` to `import_expression` when flag is set
- **Hold defaults**: add `$0\x = \x` to `root_case.actions` for ALL assigned signals before body processing; ensures registers hold value when conditionally assigned; body's unconditional assignments override the hold via later entries in `root_case.actions`
- **Structure**: `root_case.actions` (defaults) → `switch` statements (from body) → `sync posedge \clk: update \x $0\x`
- **`in_always_ff_context`** flag (separate): still used for assertion handling; not the same as `in_always_ff_body_mode`

### For Loop Unrolling in Always Blocks

For loops inside `always` blocks are compile-time unrolled using `loop_values`:

1. **Variable type matters for init detection**:
   - Local `for (int i = 0; ...)` uses `vpiRefVar` in init LHS
   - Module-level `integer k; ... for (k = 0; ...)` uses `vpiRefObj` in init LHS
   - Both must be handled when parsing the init statement to set `can_unroll = true`

2. **`extract_assigned_signals` (process_helper.cpp)** needs a `vpiFor` case so that signals assigned inside loops (e.g. `q[k]`) are detected and proper `$0\q` temp wires are created; set `lhs_expr = nullptr` for dynamic-index signals (they need full-width temp wires)

3. **`import_always_comb`**: handle `lhs_expr == nullptr` by looking up the full wire by name instead of calling `import_expression(nullptr)`

4. **`import_part_select` and `import_indexed_part_select` (expression.cpp)**: check `loop_values.count(base_signal_name)` **before** wire lookup; if found, return `RTLIL::Const(loop_val, width)` as the base — `k[1:0]` is a `vpiPartSelect` node (VpiName="k"), not a reference

5. Always call `loop_values.clear()` at the end of `import_always_ff` and `import_always_comb`

### `$display` / `$write` System Tasks in Always Blocks

- UHDM represents `$display(a, b, y)` as a `sys_func_call` node (VPI type 56 = `vpiSysFuncCall`), VpiName=`$display`
- Arguments accessed via `Tf_call_args()` (returns `VectorOfany*`; each cast to `const expr*`)
- Implementation: `import_display_stmt(call, proc_root_case, active_case)` in `process.cpp`
  - Creates a `$print` RTLIL cell with `TRG_WIDTH=0`, `TRG_ENABLE=false` (for `always @*`)
  - EN wire default=0 added to `proc_root_case->actions`, EN=1 added to `active_case->actions`
  - Uses Yosys `Fmt::parse_verilog()` to build FORMAT string from argument list
  - `$display` appends `\n` (via `fmt.append_literal("\n")`), `$write` does not
- Handler in `import_statement_comb(Process*)` (unconditional): passes `&proc->root_case` for both root and active
- Handler in `import_statement_comb(CaseRule*)` (inside `if`): uses `current_comb_process->root_case` as root, `case_rule` as active
- `UhdmImporter::last_effect_priority` (initialized to 0): decremented per `$print` cell (same as genrtlil.cc)
- Net declaration initializers (`reg a = 0`): set `\init` attribute on wire, NOT an init process
- Without `$print` cell, `$display` logic has no output consumer → `opt` removes all logic → 0 gates

### Package Parameter Resolution in Compile-Time Evaluator (`evaluate_single_operand`)

- When `evaluate_single_operand` encounters a `ref_obj` not in `local_vars`, it may be a package parameter (e.g., `X` from `P::X = 3` referenced in function body `f = i * X`)
- Fix in `functions.cpp` `evaluate_single_operand`: after failing `local_vars` lookup, check `ref->Actual_group()` — if it is a `parameter`, parse its `VpiValue()` string (`"UINT:3"`, `"HEX:..."`, `"BIN:..."`) into a `RTLIL::Const`
- Without this fix: `i * X` evaluates to `i * 0` → function returns wrong value (0 instead of 9 for `f(3)`)

### Initial Block with Task Call

- `import_initial` selects the import path based on control-flow analysis; `vpiTaskCall` at the top level is not control flow, so the sync path was chosen — which has no `case vpiTaskCall` handler
- Fix: detect `stmt->VpiType() == vpiTaskCall` and route to `import_initial_comb`; this allows `import_task_call_comb` to inline the task body and drive the output argument wire
- Pattern: `initial P::t(a)` where task `P::t` has `output integer x; x = Y;` → `a` is driven with the constant value `Y`

### Concurrent Assertions (`assert property`) in Module Scope

- UHDM stores `assert property (expr)` as `assert_stmt` nodes under `module_inst->Assertions()` (type `VectorOfconcurrent_assertions*`)
- Each `assert_stmt` has `VpiProperty()` → `property_spec` → `VpiPropertyExpr()` → the boolean expression
- Fix in `uhdm2rtlil.cpp` `import_module`: after importing processes, iterate `Assertions()`, cast to `assert_stmt`, evaluate the property expression via `import_expression`, and create a `$check` cell with `FLAVOR="assert"`, `EN=1'h1`, `TRG_WIDTH=0`
- Include `<uhdm/assert_stmt.h>` and `<uhdm/property_spec.h>` (added to `uhdm2rtlil.h`)

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