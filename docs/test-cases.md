# Test Case Catalog

> Current Test Cases (232 total — 187 passing equivalence, 45 UHDM-only, 0 known failures)
>
> Full annotated list of the internal SystemVerilog test cases, extracted from
> the main [README](../README.md).

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
- **initval** - Initial values on registers with mixed combinational and clocked part-select assignments to the same signal

#### Counters & Sequential Designs
- **simple_counter** - 8-bit counter with async reset (tests increment logic, reset handling)
- **counter** - More complex counter design
- **always01** - 4-bit synchronous counter with mux-based async reset
- **always02** - 4-bit counter with synchronous reset in nested block
- **always03** - Mixed blocking and non-blocking assignments with if-else chains
- **counters_repeat** - Repeat loop counter using `repeat(32)` with mixed blocking/non-blocking assignments and carry chain
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
- **partsel_simple** - Part selection with dynamic offset using `+:` and `-:` operators; `data[offset +: 4]` and `data[offset+3 -: 4]` where `offset = idx << 2`; synthesized via `$shiftx` cells (28 gates)
- **wreduce_test0** - Signed arithmetic with width reduction
- **wreduce_test1** - Arithmetic operations with output width reduction
- **unbased_unsized** - SystemVerilog unbased unsized literals ('0, '1, 'x, 'z) and cast operations
- **unbased_unsized_shift** - Unbased unsized fill literals (`'0`, `'1`) in shift operations: `'1 << 8` in a 64-bit context produces `64'hFFFF_FFFF_FFFF_FF00`; tests constant and dynamic shift amounts
- **port_sign_extend** - Port sign extension with signed submodule outputs, signed constants, arithmetic operations, and correct unbased unsized vs sized constant handling
- **port_int_types** - Built-in integer port types (`byte`, `byte unsigned`, `shortint`, `shortint unsigned`): signed types sign-extend and unsigned types zero-extend when assigned to wider `[31:0]` wires
- **param_int_types** - Module-level variable declarations using built-in integer types (`integer`, `int`, `shortint`, `longint`, `byte`) with initial values; also tests typed parameters (`parameter integer a = -1` etc.) — verifies correct widths and initial/parameter values
- **asgn_expr** - Assignment expressions: increment/decrement operators as statements and in expressions, nested assignment expressions
- **asgn_expr2** - Assignment expressions with input-dependent outputs (formal equivalence verified)
- **asgn_expr_sv** - Full increment/decrement test from Yosys suite: pre/post-increment/decrement as statements and expressions, byte-width concatenation (`{1'b1, ++w}`, `{2'b10, w++}`), procedural assignment expressions (`x = (y *= 2)`)
- **asgn_binop** - Compound assignment operators (`+=`, `-=`, `*=`, `/=`, `%=`, `&=`, `|=`, `^=`, `<<=`, `>>=`, `<<<=`, `>>>=`)

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
- **repwhile** - Memory initialization with `while`/`repeat` loop functions (`mylog2`, `myexp2`) called from for-loop in initial block
- **func_block** - Functions with multiple assignment patterns: `func1`/`func2` use for-loop bit-select LHS (`func1[idx] = inp[idx]`), `func3` uses part-select LHS on return variable (`func3[A:B] = inp[A:B]`) with function-local `localparam A = 32-1; parameter B = 1`; demonstrates correct localparam resolution via `param_assign->Rhs()` and `uhdmpart_select` LHS in `process_stmt_to_case`
- **const_fold_func** - Compile-time constant function evaluation: recursive functions with bitwise ops, bit-select LHS assignments, nested function calls as arguments *(2 unproven equiv cells - known failure)*

#### Scope & Variable Shadowing
- **scope_func** - Function calls with variable inputs in always blocks (tests function scope resolution)
- **scopes** - Functions, tasks, and nested blocks with variable shadowing (tests complex scoping)
- **scope_task** - Tasks with nested named blocks and local variables (tests task inlining in always blocks)
- **unnamed_block_decl** - Unnamed begin/end blocks with local integer variable declarations and variable scoping (inner z shadows output z, compile-time evaluated to z=5)

#### Arrays & Memory
- **arrays01** - 4-bit x16 array with synchronous read and write (tests memory inference)
- **arrays03** - Packed multidimensional arrays with dynamic element access (tests `logic [0:3][7:0]`, `reg8_t [0:3]`, and typedef variants)
- **simple_memory** - Memory arrays and access patterns
- **simple_memory_noreset** - Memory array without reset signal
- **blockrom** - Memory initialization using for loops with LFSR pattern (tests loop unrolling and constant evaluation)
- **priority_memory** - Priority-based memory access patterns
- **mem2reg_test1** - Combinational array with dynamic write and read in `always @*`: `array[dyn_addr] = in_data; out = array[out_addr]` — correctly synthesized with individual element wires and mux chains ✅
- **mem2reg_test2** - `(* mem2reg *)` annotated 8-element array with for-loop writes and dynamic address read/write in `always @(posedge clk)` ✅
- **asym_ram_sdp_read_wider** - Asymmetric RAM with read port 4x wider than write
- **asym_ram_sdp_write_wider** - Asymmetric RAM with write port 4x wider than read
- **sp_read_first** - Single port RAM with read-first semantics
- **sp_read_or_write** - Single port RAM with read-or-write semantics
- **sp_write_first** - Single port RAM with write-first semantics

#### Data Types & Structs
- **simple_struct** - Packed struct handling and member access (tests struct bit slicing)
- **struct_array** - Arrays of packed structs with complex indexing and member access
- **struct_access** - Packed struct field access with initial block assignments; fixed `'1` fill constant extension (4-bit field now gets `4'b1111`, not `4'b0001`)
- **nested_struct** - Nested structs from different packages with complex field access *(UHDM-only)*
- **nested_struct_nopack** - Nested structs without packages (tests synchronous if-else with switch statements)
- **simple_nested_struct_nopack** - Simpler nested struct test without packages
- **enum_simple** - State machine with typedef enum and state transitions
- **enum_values** - Multiple enum types with custom values and attributes
- **svtypes_enum_simple** - Bare enums, typedef enums, parenthesized type declarations, enum constant init, FSM with assertions
- **svtypes_struct_simple** - Packed structs with member access (`s.a`, `pack1.b`), nested struct member access (`s2.b.x`), `struct packed signed`, continuous assignments and combinational assertions
- **typedef_simple** - Multiple typedef definitions with signed/unsigned types
- **typedef_param** - Typedef'd parameters and localparams with signed types, chained typedef aliases (`char_t` = `int8_t` = `logic signed [7:0]`), localparam visibility (only `parameter` exported, `localparam` hidden), and static assertions
- **typedef_package** - Package-scoped typedefs, enum types with hex values, package localparam/parameter from enum constants, package-qualified assertions
- **package_task_func** - Package tasks (`P::t`) and functions (`P::f`, `P::g`) called from module scope, including recursive functions and `localparam` resolution across package boundaries, with concurrent `assert property` statements
- **union_simple** - Packed unions: named unions (`w_t`, `instruction_t`), anonymous unions with nested struct, unions nested within structs (`s_t`), multi-level member access through union and struct boundaries

#### Generate & Parameterization
- **param_test** - Parameter passing and overrides
- **generate_test** - Generate for loops and if-else generate blocks with proper instance naming
- **simple_generate** - Generate loop with AND gates clocked per-bit
- **forgen01** - Generate block with nested loops computing prime LUT
- **forgen02** - Generate block implementing parameterized ripple adder
- **gen_test1** - Nested generate loops with if-then conditional blocks and sequential always blocks
- **gen_test2** - For-loop in always block with casez carry propagation
- **gen_test3** - Conditional generate with if/case and multi-assign statements
- **gen_test4** - Hierarchical generate with localparam cross-references (`foo[PREV].temp`)
- **gen_test5** - Nested generate with multiplication-based genvar increment (`step = step * CHUNK`) and cross-scope hierarchical references (`steps[PREV].outer[LAST_START].val`)
- **gen_test6** - Descending generate for-loop (`i = 3; i >= 0; i = i-1`)
- **gen_test7** - Generate with initial/always blocks and power operator (`2 ** 2`)
- **gen_test8** - Nested generate scope shadowing with wire constant initialization
- **gen_test9** - Named generate blocks with scope shadowing and XOR computation
- **genblk_order** - Nested generate blocks with variable shadowing
- **genvar_loop_decl_1** - Generate loop with inline genvar declaration and width arrays
- **genvar_loop_decl_2** - Generate with genvar shadowing and hierarchical references
- **carryadd** - Generate-based carry adder with hierarchical references
- **multiplier** - 4x4 2D array multiplier with parameterized RippleCarryAdder and FullAdder using generate loops *(known equiv mismatch - SAT proves outputs equivalent)*
- **const_func** - Constant functions in generate blocks with string parameters, `$floor`, and bitwise negation
- **forloops** - For loops in both clocked and combinational always blocks, with module-level loop variables (`integer k`), indexed bit-select LHS (`q[k]`), indexed part-select LHS (`p[2*k +: 2]`), and part-select RHS (`{~a,~b,a,b} >> k[1:0]`)
- **case_expr_const** - Case statement with constant expressions including signed case items, mixed signed/unsigned contexts, and context-width extension per SV LRM 12.5.1

#### Module Hierarchy & Interfaces
- **simple_hierarchy** - Module instantiation and port connections
- **simple_interface** - Interface-based connections
- **simple_instance_array** - Primitive gate arrays (and, or, xor, nand, not with array instances) *(UHDM-only)*
- **simple_package** - SystemVerilog packages with parameters, structs, and imports *(UHDM-only)*
- **custom_map_incomp** - Custom technology mapping with `_TECHMAP_REPLACE_` cell and string parameters
- **arraycells** - Array cell instantiation with bit-sliced port connections (e.g., `aoi12 p [31:0] (a, b, c, y)`)
- **recursive_map** - Verbatim port of `yosys/tests/techmap/recursive_map.v`: a single-module file with a self-referential `_TECHMAP_REPLACE_` instance and a forward reference to undefined `bar`; tests `Ref_modules()` import for orphan modules (no top, hierarchy walk doesn't run)
- **reg_wire_error** - Verbatim port of `yosys/tests/various/reg_wire_error.sv`: mixes `wire`, `reg`, and `logic` 1-D unpacked arrays (`wire mw1[0:1]`, `reg mr1[0:1]`, `logic ml1[0:1]`) with bit-select reads/writes (`mw1[1] = 1'b1`, `o_mw = mw1[i]`); covers unpacked-array-of-wires (the `array_net` case that was a TODO) and bit-select-only `array_var` flattening
- **struct_param_dim** - Array dimension defined by a field of a struct-typed parameter: `parameter test_struct_t pt = 32'h4; logic mem[pt.t];`. The elaborated UHDM stores the right range bound as a `vpiOperation` (`pt.t - 1`) rather than a `vpiConstant`, so range-bound evaluation needs to fold the operation via `import_expression`. Regression test for the synlig/Surelog segfault on VeeR EL2

#### Primitives & Miscellaneous
- **verilog_primitives** - Instantiation of buf, not, and xnor primitives
- **escape_id** - Module and signal names with special characters and escapes
- **code_hdl_models_decoder_2to4_gates** - 2-to-4 decoder using primitive gates
- **code_hdl_models_parallel_crc** - 16-bit parallel CRC with combinational feedback logic
- **aes_kexp128** - AES key expansion circuit with XOR feedback and array registers
- **simple_abc9** - ABC9 test collection with blackbox, whitebox, and various port types
- **vector_index** - Bit-select assignments on vectors (tests `assign wire[bit] = value` syntax)
- **constmsk_test** - OR reduction of concatenations with constant bits (tests `|{A[3], 1'b0, A[1]}` and `|{A[2], 1'b1, A[0]}`)
- **rotate** - Barrel shift rotation (from Amber23 ARM core) with nested generate loops (5 levels x 32 bits), bit-select assignments in `always @*` blocks, and `wrap()` function for circular indexing
- **wandwor** - `wand` and `wor` net types with multi-driver resolution via AND/OR logic, module instance port connections, and multi-bit variants
- **fmt_always_comb** - `$display` system task in combinational `always @*` block with conditional enable (`if (y & (y == (a & b))) $display(a, b, y)`); generates `$print` RTLIL cell with TRG_WIDTH=0 (no clock triggers), EN wire controlled by the `if` condition; `reg a = 0`/`reg b = 0` net declaration initializers produce `\init` wire attributes; formally equivalent to Yosys Verilog frontend

## UHDM-only Verified Tests (Verilator co-simulation)

The original UHDM-only verification (random-constraint Verilator co-sim: the original `dut.sv`
(RTL) and the UHDM-frontend's post-`synth -auto-top` gate-level netlist instantiated side-by-side
in a testbench with shared clocks/resets and randomized inputs, outputs compared cycle by cycle):
  - `nested_struct` - Complex nested structures
  - `simple_instance_array` - Instance array support
  - `simple_package` - Package support
  - `unique_case` - Unique case statement support
  - `gen_struct_access` - Packed array of structs with field access in generate blocks
  - `setundef` - `2'b0x` (X bits) passed as a parameter override; ported from `third_party/yosys/tests/various/setundef.sv`
  - `param_no_default` - Module parameters without default values (`parameter w`, `parameter byte y`); ported from `third_party/yosys/tests/verilog/param_no_default.sv`
  - `unbased_unsized_param` - Fill literals (`'0`/`'1`/`'x`/`'z`) passed as `set_param #('0)` parameter values plus `localparam` assignments; ported from `third_party/yosys/tests/verilog/unbased_unsized.sv`
  - `sva_basic00` - SVA `assert property ( disable iff (reset) antecedent |=> consequent )` with non-overlapping implication; ported from `third_party/yosys/tests/sva/basic00.sv`
  - `sva_basic01` - SVA labeled property assertions (`a_rw: assert property (...)`); ported from `third_party/yosys/tests/sva/basic01.sv`
  - `sva_basic02` - SVA assertions placed via `bind` from a separate properties module; ported from `third_party/yosys/tests/sva/basic02.sv`
  - `sva_basic03` - SVA `$past()` system function in implication assertions; ported from `third_party/yosys/tests/sva/basic03.sv`
  - `sva_counter` - SVA `default clocking` / `default disable iff`, `$past`, sequence repetition `up [*2]`, parameterised property `down_n(n)`; ported from `third_party/yosys/tests/sva/counter.sv`
  - `sva_not` - SVA `not (ping ##1 !pong [*maxdelay])` with sequence repetition; ported from `third_party/yosys/tests/sva/sva_not.sv`
  - `sva_throughout` - SVA `throughout` operator (`a |=> b throughout (c ##1 d)`); ported from `third_party/yosys/tests/sva/sva_throughout.sv`
  - `sva_range` - SVA `##[*]` consecutive repetition and `until`; ported from `third_party/yosys/tests/sva/sva_range.sv`
  - `sva_value_change_changed` - SVA `$changed()` value-change function; ported from `third_party/yosys/tests/sva/sva_value_change_changed.sv`
  - `sva_value_change_changed_wide` - SVA `$changed()` over multi-bit values, with bit-decomposition equality assertion; ported from `third_party/yosys/tests/sva/sva_value_change_changed_wide.sv`
  - `sva_value_change_rose` - SVA `$rose()` value-change function; ported from `third_party/yosys/tests/sva/sva_value_change_rose.sv`
  - `sva_value_change_sim` - SVA `$rose`/`$fell`/`$stable` system functions with explicit `@(posedge clk)` clocking, plus an FSM-driven assertion sequence; ported from `third_party/yosys/tests/sva/sva_value_change_sim.sv`
  - `struct_pattern_loop` - Multi-dim packed-then-unpacked output port (`output bit [0:0][0:0] b [0:0]`) assigned with an unpacked-array pattern (`'{'b0}`); regression test for an upstream "ABC combinational loop" report on the same construct (which the Yosys Verilog frontend doesn't parse)
  - `hier_undriven_port` - Inner module declares a 3-bit output but doesn't drive it; outer module connects `.a1(b2)` where `b2` is an implicit 1-bit net also driven by `assign b2 = 'b0;`. Regression test for the synlig hierarchy-pass error "Output port ... is connected to constants"
