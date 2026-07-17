# Recent Improvements

> Annotated changelog of SystemVerilog features and bug fixes landed in the
> UHDM→RTLIL frontend. Extracted from the main [README](../README.md) to keep it
> concise; newest entries are near the top.

### Unpacked-Array-of-Typedef Ports Flatten to RTLIL (`typedef_unpacked_input`)
- Test: `parameter int cW = 14; typedef logic [cW-1:0] ptab_dat_t; input ptab_dat_t iP[4]; ... assign o = iP[sel];`
- **Bug — elaborated parameterized port lost its unpacked dimension**: Surelog's parameterized variant of `ccsds_turbo_enc_paddr_gen` exposed `iP` with `port->Typespec()->Actual_typespec()` resolving to the inner element type (`logic_typespec`, 14 bits) instead of the outer `array_typespec` (which the unparameterized form has). The frontend created a 14-bit port wire and 14-bit per-element wires that were never connected to slices of the port, yielding an all-`'x` netlist (no mux for `iP[sel]`).
- **Fix in `module.cpp`** (`import_port`): when `current_instance` is a `module_inst` and its `Array_nets()` contains an entry matching the port name, recover the unpacked-array dimensions from `array_net::Ranges()` and the inner `Nets()` element width. Resize the port wire to `element_width * count` (= 56), then create per-element wires `\name[0..N-1]` and `module->connect()` each to its slice of the flat port wire (input/inout) or vice versa (output) so `import_bit_select` sees the per-element wires and the synth path produces a real mux.
- **Fix in `module.cpp`** (`get_width_from_typespec`): added an `uhdmarray_typespec` case that multiplies the element width by the product of `Ranges()` (mirroring the existing `packed_array_typespec` case), so the unparameterized form also sizes the port correctly.

### `packed_array_typespec` Width Computation (`typedef_packed_enum_array`)
- Test:
  ```sv
  typedef enum { FALSE, TRUE } u;     // implicit base = int (32 bits)
  typedef u [0:1] crash;              // should be 2 * 32 = 64 bits
  ```
  The name `crash` was reported to segfault synlig; Surelog no longer crashes on this construct, but the elaborated typespec width came out wrong on the UHDM frontend.
- **Bug — `get_width_from_typespec` had no case for `packed_array_typespec`**: the fall-through used `ExprEval::size()` which reports only the range count (2) for these typespecs instead of `range_count * sizeof(element)`. With an implicit-base enum (defaulting to `int`/32 bits per LRM), the result was 1 bit instead of 64 bits, breaking equivalence with the Yosys Verilog frontend on any design that uses a packed-array typedef of an enum.
- **Fix in `module.cpp`** (`get_width_from_typespec`): added a `uhdmpacked_array_typespec` case that walks `Elem_typespec()->Actual_typespec()` (or resolves via `package_typespec_map` when no `Actual_typespec` is set) for the element width, then multiplies by the product of `Ranges()`. Element-typespec recursion picks up the existing implicit-base-enum default (`Base_typespec()` null → 32 bits).

### Function-Local Unpacked Arrays in Compile-Time Evaluation (`func_local_array`)
- Test:
  ```sv
  function [1:0] func1(input [1:0] a);
    reg [3:0] state[4];
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
      state[i] = 2'b0;
      state[i][i] = 1'b1;
    end
    func1 = state[0] ^ a;
  endfunction
  ```
  Compile-time evaluation must produce `func1(2'd3) = 4'b0001 ^ 2'b11 = 2'b10` (`out = 2'h2`)
- **Bug 1 — `evaluate_function_stmt` had no `vpiFor` case**: the for-loop was silently skipped, so `state` stayed all-zeros and `state[0] ^ 3` returned `3` instead of `2`
- **Bug 2 — array_var width came out as element width, not total**: `array_var::Ranges()` is empty in Surelog's elaborated output; the unpacked dimensions live in `array_var::Typespec()->Actual_typespec()` (an `array_typespec`) under its `Ranges()`. Result: `state` was allocated 4 bits instead of 16 (4 elements × 4 bits)
- **Bug 3 — bit_select/var_select access on `local_vars` had no array semantics**: `state[i]` LHS was treated as bit-write (set bit `i` of `state`) rather than element-write (write `element_width` bits at offset `i*element_width`); `state[i][j]` (vpiVarSelect) had no LHS or RHS handler at all
- **Bug 4 — vpiRefVar LHS was unhandled**: for-loop init `i = 0` uses `vpiRefVar` (not `vpiRefObj`), so the assignment was silently dropped, the loop never advanced and hit the iteration limit
- **Fix in `functions.cpp`** (`evaluate_function_stmt` + `evaluate_single_operand`):
  1. Added `vpiFor` case that runs init (single + vector forms), evaluates condition each iteration, runs body then inc, with a 100k iteration cap
  2. Added `vpiRefVar` LHS handling alongside `vpiRefObj`
  3. Flattened storage layout for function-local `array_var`: `local_vars[name]` is a single Const of `total_elements * element_width` bits, with element widths tracked in a new `array_local_element_widths` map
  4. New LHS handlers for bit_select and var_select on array_var: splice `element_width` bits at `idx * element_width`, or set a single bit at `i*ew + j`
  5. New RHS handlers in `evaluate_single_operand` for bit_select and var_select on array_var, mirroring the LHS layout
  6. Per-call save/restore of `array_local_element_widths` so recursion doesn't leak

### Narrow Output-Port Width Mismatch Protection (`hier_undriven_port`)
- Regression test for a synlig hierarchy-pass error: `Output port b.a_inst.a1 (a) is connected to constants: { ... 1'0 }` on
  ```sv
  module a (output logic [4:2] a1, output logic a2); endmodule
  module b (output logic b1);
    a a_inst(.a1(b2), .a2(b1));
    assign b2 = 'b0;
  endmodule
  ```
- **Bug — narrow actual on a wide output port produced constant-padded port connections**: `b2` is an implicit 1-bit net (Surelog declares it 1-bit per LRM), connected to a 3-bit output port `a1`. Yosys's hierarchy pass auto-pads the connection with `1'b0` constant bits; after `proc; opt`, the `assign b2 = 'b0` makes bit 0 also constant; a later hierarchy pass detects the cell output is connected to constants and errors
- **Fix in `uhdm2rtlil.cpp`** (`import_module_hierarchy`, port-connection loop): when the actual `conn` is narrower than the cell's output port, allocate a wider intermediate wire and pass it to `setPort` so the cell drives a real (X-valued) wire. If the original narrow actual already has another driver in the parent's `connections()` (the multi-driver case above), don't connect bit 0 of the wide wire back into it — let the explicit assign win. Otherwise, splice the lower bits through to the original wire so single-driver narrow connections keep working
- **Test runner improvement** (`run_all_tests.sh`): added a classifier for "UHDM completes synth where Verilog synth errors" — Verilog's `from_verilog.il` is written before `synth -auto-top` so it exists even when synth later errors; previously the runner mis-classified this as a failure

### Whole-Array Detection on Sub-Instance Port Connections (`struct_pattern_loop`)
- Regression test for a synlig "ABC combinational loop" report on `module a (output bit [0:0][0:0] b [0:0]); assign b = '{'b0}; endmodule`
- **Bug — port connections weren't scanned for whole-array references**: the pre-scan that populates `whole_array_accessed_names` walked only `Cont_assigns()` and `Process()`, missing `inst (.b(b_internal))` where `b_internal` is the actual on a sub-instance port. With the array marked as bit-select-only, the importer split it into per-element wires (`\b_internal[0]`) AND the port-connection path created a separate single wire (`\b_internal`) — only the single wire got driven, so the per-element reads (`b_internal[0][0][0]`) returned `'x`
- **Fix in `uhdm2rtlil.cpp`** (`import_module`, pre-scan): also walk `Modules()` and `Ref_modules()`, scanning each port's `High_conn()` so the actual is treated the same as an LHS/RHS reference

### Range Bounds From Struct-Field Parameters (`struct_param_dim`)
- Synthesizable regression test for the synlig/Surelog segfault on VeeR EL2: `parameter test_struct_t pt = 32'h4; logic mem[pt.t];` — array dimension is a field of a struct-typed parameter
- **Bug — range-bound evaluation only handled `vpiConstant`**: in elaborated UHDM the right range of `[pt.t]` is stored as a `vpiOperation` (`pt.t - 1`, where `pt.t` is itself a folded constant), not a literal `vpiConstant`. The 1-D unpacked-array-var path's range-bound code only checked `VpiType() == vpiConstant`, so size silently fell back to 1 and only `\mem[0]` was created
- **Fix in `uhdm2rtlil.cpp`** (`import_module`, `Variables()` loop, 1-D unpacked array_var branch): added an `eval_bound` lambda that runs `import_expression` on either left or right range bound and uses `as_const().as_int()` when the result is fully constant. Handles both `vpiConstant` and arbitrary fold-able operations like `pt.t - 1`, `WIDTH - 1`, etc.

### Unpacked Arrays of Wires + Conditional Flatten of `logic` Arrays (`reg_wire_error`)
- Verbatim port of `yosys/tests/various/reg_wire_error.sv`: a `test` module with `wire mw1[0:1]`, `reg mr1[0:1]`, and `logic ml1[0:1]` unpacked arrays, accessed by bit-select (`mw1[1] = 1'b1`, `o_mw = mw1[i]`)
- **Bug 1 — unpacked-array-of-wires was a TODO**: `array_net` import code had a final `else` branch that logged "skipping memory creation" and did nothing; `import_bit_select` then errored with `"Could not find wire 'mw1' for bit select"`
- **Fix in `uhdm2rtlil.cpp`** (`import_module`, `Array_nets()` loop): for `array_net` with no packed dims, create per-element single-bit wires `\name[low+0]`, `\name[low+1]`, ..., using `Ranges()[0]` for the unpacked range and the inner `Nets()[0]`'s width for the element width
- **Bug 2 — `logic ml1[0:1]` (`array_var` with no packed dims) created a single 1-bit wire**, dropping all per-element values; flattening to per-element wires unconditionally would have regressed `array_assign` (test 8 has `pt_o = pt_sel ? pt_a : pt_b` whole-array assignment, which the LHS handler can't currently route to per-element wires)
- **Fix in `uhdm2rtlil.cpp`** (`import_module`, `Variables()` loop): added a pre-scan that walks `Cont_assigns()` and `Process()` collecting names of `vpiRefObj` nodes that are NOT the base of a `bit_select` / `var_select` / `indexed_part_select` / `part_select` (i.e. whole-array references). For 1-D unpacked `array_var`s NOT in this set (= bit-select-only access), flatten to per-element wires; otherwise keep the legacy single-1-bit-wire fallback so the existing array-to-array assignment path keeps working
- All 195 tests pass (172 equivalence + 23 UHDM-only, 0 known failures) — no regressions ✅

### `Ref_modules()` Import for Orphan Modules and User-Attribute Propagation (`recursive_map`)
- Verbatim port of `yosys/tests/techmap/recursive_map.v`: `module sub; sub _TECHMAP_REPLACE_(); bar f0(); endmodule` — a single, top-less file with a self-referential `_TECHMAP_REPLACE_` and a forward reference to undefined `bar`
- **Bug — empty UHDM module body**: with no top module the elaborated hierarchy walk doesn't run, and the AllModules importer only processed `module_inst::Modules()` (always empty in AllModules); both child cells were silently dropped
- **Fix in `uhdm2rtlil.cpp`** (`import_design`): pre-walk each top via `Modules()` and record every visited `VpiDefName` in `hierarchy_reachable_modules`; this is the set of modules whose child cells are guaranteed to be created by `import_module_hierarchy`
- **Fix in `uhdm2rtlil.cpp`** (`import_module`): for any module NOT in `hierarchy_reachable_modules` (e.g. orphan modules with no top, like a stand-alone techmap library file), iterate `Ref_modules()` and call `import_ref_module()` for each — handling self-references and forward refs that the hierarchy walk would otherwise miss
- **Fix in `uhdm2rtlil.cpp`** (`import_module`): also propagate user attributes from `module_inst::Attributes()` (`(* blackbox *)`, `(* whitebox *)`, `(* abc9_box *)`, `(* gentb_skip *)`, etc.) to `module->attributes` — needed for any blackbox techmap libraries even when reachable from a top
- **Fix in `ref_module.cpp`** (`import_ref_module`): existence guard against double-creation, plus `\src` and `\module_not_derived = 1` attributes on the created cell (matching the Verilog frontend's output for unelaborated cells)
- **Test discovery in `run_all_tests.sh`**: discover tests with `dut.v` in addition to `dut.sv` so plain-Verilog ports of upstream Yosys tests are picked up
- Both UHDM and Verilog frontends now produce identical RTLIL for `recursive_map.v`; the test passes by comparing pre-hierarchy `_nohier.il` files (both paths fail at hierarchy with the same `\bar not part of the design` error, by design)
- All 195 tests now pass (172 equivalence + 23 UHDM-only, 0 known failures) ✅

### Unbased Unsized Fill Constant Extension (`'1`)
- Fixed `'1` fill constants assigned to multi-bit struct fields (and any multi-bit LHS in `import_assignment_sync`)
- UHDM represents `'1` as `VpiSize() == -1`, `VpiValue() == "BIN:1"` — `import_constant()` returns a 1-bit `SigSpec(S1)` since it has no target-width context
- **Bug**: the assignment handler called `extend_u0()` (zero-extend) when RHS was narrower than LHS, producing `4'b0001` for a 4-bit field instead of `4'b1111`
- **Fix in `process.cpp`** (`import_assignment_sync`): detect fill-ones RHS before importing by checking `c->VpiSize() == -1 && VpiValue() == "BIN:1"`, then on size mismatch replicate `S1` to the full LHS width (`SigSpec(S1, lhs.size())`) instead of zero-extending
- **Fix in `interpreter.cpp`** (`evaluate_expression`): return `-1LL` for `'1` fill constants so `RTLIL::Const(-1, wire->width)` in `import_initial_interpreted` also produces correct all-ones (two's-complement `-1` is all bits set for any width)
- `struct_access` test now produces `assign s = 30'h3fffffff` (all 30 bits 1), formally verified ✅

### Generate-Scope Variable Shadowing in Named Begin Blocks
- Fixed `gen_test7`: `always @* begin : proc` block declaring `reg signed [31:0] x` was incorrectly using the generate-scope genvar `\cond.x` (1-bit) instead of the block-local `\proc.x` (32-bit)
- Root cause: `import_ref_obj()` tries `gen_scope + "." + ref_name` (e.g., `"cond.x"`) before the plain `name_map[ref_name]` lookup — this bypassed the block-local shadow
- **Fix in `process.cpp`** (`import_begin_block_comb`): when shadowing `name_map[var_name]` with the block-local wire, also shadow the gen-scope hierarchical name `name_map[gen_scope + "." + var_name]`; both entries are added to `block_local_vars` for restore on exit
- `gen_test7` now produces `out2 = 2` (was `0`), formally verified ✅

### Robust Formal Equivalence for Constant-Only Circuits
- Fixed `test_equivalence.sh`: when no `$_` gate cells are present (constant-only module), the script previously wrote `# No gates to check` and exited 0 — a vacuous pass
- **Fix**: compare `assign signal = VALUE;` lines common to both gold (Verilog) and gate (UHDM) netlists; normalise `?`→`x` for high-Z equivalence; skip signals where gold already has undefined bits
- `port_sign_extend` equivalence check now passes correctly

### Case Statement Signed/Unsigned Context Extension (`case_expr_const`)
- Fixed `import_case_stmt_comb` and the nested `import_statement_comb` (CaseRule* variant) to correctly implement SV LRM 12.5.1 case-statement comparison semantics
- **Bug 1 — wrong concatenation direction**: code used `{expr_sig, zeros}` (Verilog-style concat puts `expr_sig` at the MSB side, zeros at the LSB), effectively left-shifting the value; `1'sb1` → `2'10` (value 2) instead of `2'01` (zero-extended) or `2'11` (sign-extended)
- **Bug 2 — missing sign extension**: signed case items such as `1'sb1` (= −1) must be sign-extended to the context width; zero-extending gives value 1, which does not match `2'sb11`
- **Bug 3 — wrong context width**: the switch signal width was taken from the case expression alone; when a case item is wider (e.g., `3'b0` in `case (1'sb1)`), the comparison must occur at the wider width to avoid spurious matches
- **Fix**: two-pass approach in `import_case_stmt_comb`:
  1. Import case expression and all case-item expressions; track width and signedness of each
  2. Context width = max of all; context signed = all operands signed (any unsigned → unsigned context)
  3. Extend switch signal and each compare value to context width using `extend_u0(width, is_signed)` — sign-extends when both context and that operand are signed, otherwise zero-extends
- Added `is_expr_signed()` helper that checks the `'s` sigil in `VpiDecompile()` (e.g. `"1'sb1"`, `"2'sb11"`) to determine constant signedness
- `case_expr_const` now formally verified: all 8 outputs produce `1'h1` ✅

### Port Sign Extension Equivalence Check (`port_sign_extend`)
- The UHDM frontend was already producing correct output for this test — `GeneratorSigned2.out` and all sign/zero-extension logic were right
- **Root cause of false failure**: `test_equivalence.sh` compared constant `assign` statements with a naive file-wide `grep`, making `assign out = 2'h2` (from `GeneratorSigned2`) match `assign out = 1'h1` (from `GeneratorSigned1`) since grep returns the first occurrence in a multi-module file
- **Fix**: replaced the line-by-line shell loop with a single `awk` pass that tracks the current `module` declaration and keys the gate lookup table as `module:signal`; the gold file is then compared against the same `module:signal` key, ensuring cross-module name collisions are never compared
- `port_sign_extend` now passes with 18 common constant assignments verified ✅

### Unnamed Block Variable Declaration Support
- Added interpreter-based evaluation path for initial blocks containing block-local variable declarations
- `block_has_local_variables()` helper recursively detects `Variables()` on `begin`/`named_begin` blocks in the UHDM statement tree
- Extended `interpret_statement()` in `interpreter.cpp` to save/restore block-local variables for proper scoping:
  - Before entering a begin block: saves existing variable values and initializes block-local vars to 0
  - After exiting: restores saved values or erases block-local vars that didn't exist in the outer scope
- New `import_initial_interpreted()` method runs the interpreter, then creates `STi` sync actions for variables that correspond to module-level wires
- Handles variable shadowing: inner block's `integer z` correctly shadows the module output `z`, with the shadow removed on block exit
- `import_initial()` now has three routing strategies: interpreter (block-local vars), comb (case/if), sync (default)
- Test `unnamed_block_decl` verifies the complete scoping chain produces `z = 5` through nested begin blocks

### Wand/Wor Net Type Support
- Added `wand` (wire-AND) and `wor` (wire-OR) net type propagation from UHDM to RTLIL
- Surelog encodes these as `VpiNetType()` values `vpiWand` (2) and `vpiWor` (3) on `logic_net` objects
- Sets `\wand`/`\wor` boolean attributes on RTLIL wires, enabling Yosys hierarchy pass to resolve multi-driver nets with AND/OR logic
- Handles both the early-return path (net already created as port) and normal net creation path in `import_net()`
- Test covers single-bit and multi-bit variants, continuous assignments and module port connections

### Compile-Time Function Evaluation with While/Repeat Loops
- Extended compile-time function evaluator (`evaluate_function_stmt`) to support `vpiWhile` and `vpiRepeat` loop constructs
- **While loops**: Evaluate condition each iteration, execute body while non-zero, with 10,000 iteration safety limit
- **Repeat loops**: Evaluate repeat count, execute body N times, with 10,000 count safety limit
- Function return width now uses actual width from `func_def->Return()` instead of hardcoded 32-bit
- Fixed `const_shl`/`const_shr`/`const_not` in compile-time evaluator: passing `-1` as result_len caused `vector::_M_fill_insert` crash (unsigned overflow in `resize`)
- Added for-loop increment handling for `i = i + 1` assignment form (in addition to `i++` post-increment)
- Added memory initialization pattern with function calls: detects `for (i=0; i<N; i++) begin mem[i] <= func(i); end` and generates `$meminit_v2` cells directly
- Enables compile-time evaluation of functions like `mylog2` (while-based) and `myexp2` (repeat-based) called from initial block for-loops
- 128 `$meminit_v2` cells generated for the `repwhile` test (64 for y_table, 64 for x_table), formally verified equivalent

### Packed Union Support
- Implemented packed union handling for `union_var` and `union_typespec` UHDM types
- **Width calculation**: Union width = width of widest member (unlike structs where width = sum of all members)
- **Member access**: Union members all overlay at bit offset 0 — accessing any member returns a slice starting at the same base offset
- **Nested access**: Supports arbitrary nesting of structs and unions (e.g., `s1.ir.u.opcode` where `s1` is a struct containing a union `ir` containing a struct `u`)
- **Variable handling**: `union_var` in Variables() import sets wiretype attribute and propagates signedness
- **Net handling**: `union_typespec` in net import (for anonymous unions via `struct_net`) sets wiretype attribute
- **Expression resolution**: Extended `import_hier_path()` and `calculate_struct_member_offset()` to handle both `struct_typespec` and `union_typespec` transparently
- All 13 assertions in the test are synthesized and formally verified correct by Yosys SAT solver

### Compound Assignment Operator Support
- Implemented all 12 compound assignment operators: `+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `<<<=`, `>>>=`
- Surelog represents compound assignments (e.g., `c += b`) as UHDM `assignment` objects with `vpiOpType` set to the operation type (`vpiAddOp`, `vpiSubOp`, etc.) rather than `vpiAssignmentOp` (regular assign)
- Added `create_compound_op_cell()` helper that maps `vpiOpType` to the corresponding RTLIL cell (`$add`, `$sub`, `$mul`, `$div`, `$mod`, `$and`, `$or`, `$xor`, `$shl`, `$shr`, `$sshl`, `$sshr`)
- The LHS's current value is resolved from `current_comb_values` tracking (e.g., after `c = a`, the compound `c += b` correctly generates `$add(a, b)` instead of `$add(c, b)`)
- Compound op handling added to both `import_assignment_comb` variants (Process and CaseRule)
- All 12 compound operator modules pass formal equivalence checking

### Packed Multidimensional Array Support
- Implemented packed multidimensional array port and net handling for all typespec variants:
  - **Variant A**: Direct multi-range (`logic [0:3][7:0]`) — 2+ ranges on a single `logic_typespec`
  - **Variant B**: Elem_typespec-based (`reg8_t [0:3]`) — `logic_typespec` with `Elem_typespec` pointing to element type
  - **Typedef aliases**: (`reg2dim1_t` = `typedef reg8_t [0:3]`) — nested Elem_typespec chains
- Fixed wire width computation in `get_width_from_typespec()`: multiplies element width by range size for Elem_typespec variants, with typedef alias detection to avoid double-counting
- Fixed upto/start_offset in `import_port()` and `import_net()`: packed multi-dim arrays create flat wires (no `upto` flag) since they're treated as flattened bit vectors in RTLIL
- Dynamic element access (`in[ix]`) in `import_bit_select()` generates proper arithmetic cells:
  - For `[0:N]` (ascending) ranges: `$sub(N, ix)` → `$mul(result, elem_width)` → `$shiftx(base, offset, Y_WIDTH=elem_width)`
  - For `[N:0]` (descending) ranges: `$mul(ix, elem_width)` → `$shiftx(base, offset, Y_WIDTH=elem_width)`
- Packed array metadata (`packed_elem_width`, `packed_outer_left`, `packed_outer_right`) stored as wire attributes during port import for reliable detection in expression handler
- All 4 test modules (pcktest1–4) pass formal equivalence checking

### Repeat Loop Support
- Implemented `vpiRepeat` handler in `import_statement_sync()` for compile-time unrolling of `repeat(N)` loops
- Analyzes body statements to classify blocking assignments into loop index variables and intermediate variables
- Loop index variables (detected by `var = var + 1` pattern) are handled via `loop_values` for compile-time substitution in bit-selects
- Blocking intermediate variables (like `carry`) are handled via `input_mapping` for runtime signal chain propagation
- Non-blocking assignments are added directly to sync rule actions with resolved bit indices
- Initial values for blocking variables are read from `pending_sync_assignments` (preceding statements)
- Final values are written back to `pending_sync_assignments` for correct flush at process end
- Safety limit of 100,000 iterations; non-constant repeat counts produce a warning
- Formally verified: produces functionally equivalent output to Yosys Verilog frontend

### Assignment Expressions and Increment/Decrement Operators
- Implemented SystemVerilog assignment expressions: `x = (y = z + 1) + 1`
- Implemented increment/decrement operators as both statements (`x++`, `--x`) and expressions (`z = ++x`, `y = w++`)
- **Surelog fix**: Pre-increment/decrement (`++x`/`--x`) was incorrectly mapped to `vpiPostIncOp`/`vpiPostDecOp` — fixed two code paths in `CompileExpression.cpp` to emit `vpiPreIncOp`/`vpiPreDecOp` for prefix operators
- Pre-increment returns the **new** value (after modification); post-increment returns the **old** value (before modification)
- Handles `vpiPostIncOp`/`vpiPreIncOp`/`vpiPostDecOp`/`vpiPreDecOp` (ops 62-65) in `import_operation()` and `import_statement_comb()`
- Handles `vpiAssignmentOp` (op 82) for nested assignment-as-expression in `import_operation()`
- Side-effect operations are handled before `reduceExpr` to prevent incorrect constant folding
- Added `emit_comb_assign()` helper for emitting process assignments with proper `$0\` temp wire mapping
- Added `map_to_temp_wire()` helper for mapping signals to their temp wire equivalents
- Value tracking (`current_comb_values`) updated after each side-effect to ensure correct data flow chaining
- Separate value-tracked and non-tracked imports: tracked values for cell inputs (correct data flow), raw wires for side-effect targets (correct assignment targets)

### Port Signedness and Sign Extension
- Fixed signed port propagation from UHDM elaborated nets to port wires
- In `import_net()`, when a net already exists in `name_map` (created by `import_port()`), the `VpiSigned` flag is now checked and applied to the existing wire
- Added operation signedness analysis: arithmetic, comparison, and shift operations check both operands for signedness
- Signed constant detection via `int_typespec` on `Actual_typespec()` for constants like `1'sb1`
- Unbased unsized literal extension (`'0`, `'1`, `'x`, `'z`) guarded by `VpiSize() == -1` — sized constants like `1'b1` (`VpiSize() == 1`) are no longer incorrectly replicated to port width
- Re-enabled AllModules import with top-level skip for proper port direction information on non-top modules

### Techmap Cell Handling (_TECHMAP_REPLACE_)
- Special handling for `_TECHMAP_REPLACE_` instances: no blackbox module definition is created
- Cell is created with the base module name (parent namespace stripped, e.g., `custom_map_incomp::ALU` → `ALU`)
- Parameters are passed directly on the cell with proper string constant preservation (`"AND"` not binary)
- Port connections are made directly from the parent module's wires
- Test infrastructure updated to handle tests where both frontends fail at `hierarchy -check` by comparing nohier IL outputs

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
- Fixed for-loop unrolling in `always @(posedge clk)` and `always @*` blocks:
  - Module-level loop variables (`integer k;`) use `vpiRefObj` in the for-loop init node — now handled alongside `vpiRefVar` (local loop variables)
  - `extract_assigned_signals` recurses into `vpiFor` bodies; dynamically-indexed signals (`q[k]`) get full-width `$0\` temp wires with `lhs_expr = nullptr`
  - `import_part_select` / `import_indexed_part_select` substitute `loop_values[k]` as a constant before resolving the base wire, preventing `k[1:0]` from emitting a live wire reference during unrolling

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
- `asym_ram_sdp_write_wider` restored to passing after always_ff comb-path regression (see Recent Fixes)

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
