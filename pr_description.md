# Fix generate scope handling and parameter resolution

## Summary
This PR fixes several test failures related to generate scope handling and parameter resolution in the UHDM to RTLIL frontend. The changes improve SystemVerilog generate block support and fix parameter value parsing issues.

## Changes Made

### 1. Generate Scope Stack Implementation
- Added a generate scope stack to track nested generate blocks
- Properly handles hierarchical naming for signals in generate blocks
- Supports both generate for loops and conditional generate blocks

### 2. Parameter Resolution Improvements  
- Fixed parameter value resolution when `ref_obj->Actual()` points to a parameter
- Added support for HEX and BIN parameter value formats (e.g., `HEX:AA`, `BIN:1010`)
- Improved parameter lookup in module default values

### 3. Net Import from Generate Scopes
- Fixed issue where nets (not just variables) weren't being imported from generate scopes
- Ensures all signals declared in generate blocks are properly accessible

### 4. Loop Variable Substitution
- Added support for loop variable substitution in expressions within for loops
- Properly handles memory indexing with loop variables (e.g., `RAM[{addrA, lsbaddr}]`)

## Tests Fixed
✅ **simple_generate** - Generate for loops with bit-select assignments  
✅ **gen_test1** - Generate blocks with nets and wires  
✅ **asym_ram_sdp_read_wider** - Asymmetric RAM with for loops and memory reads  
✅ **asym_ram_sdp_write_wider** - Asymmetric RAM with for loops and memory writes  
✅ **param_test** - Parameterized modules with HEX parameter values  

## Test Results
- **Total tests**: 77
- **Passing tests**: 73 (94% success rate)
- **Known failures**: 4 (carryadd, case_expr_const, forloops, mem2reg_test1)

## Technical Details

### Files Modified
- `src/frontends/uhdm/expression.cpp` - Parameter resolution and loop variable substitution
- `src/frontends/uhdm/module.cpp` - Net imports from generate scopes
- `src/frontends/uhdm/uhdm2rtlil.h` - Generate scope stack data structures

### Key Fixes
1. **Generate scope naming**: Signals in generate blocks now get proper hierarchical names (e.g., `gen_loop[0].tmp`)
2. **Parameter formats**: Added parsing for HEX/BIN parameter values instead of just decimal
3. **Net visibility**: Generate blocks now properly export both variables and nets to parent scope
4. **Loop unrolling**: For loops in always blocks properly substitute loop variables in expressions

## Verification
All fixed tests now pass formal equivalence checking between UHDM and direct Verilog paths, confirming functional correctness of the implementation.
