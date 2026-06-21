# Frontend Regression Matrix

Tests: **653**  ·  cycles=100  ·  frontends=verilog,uhdm,sv2v,slang

## Leaderboard

`Read + synth(gate)` = read OK, netlist has logic gates; `Read + synth(const)` = read OK but folds to a constant netlist (0 gates). Both count toward Correct/Incorrect/Unknown.

| Frontend | Read + synth(gate) | Read + synth(const) | Failed | Crash | Missing | Correct | Incorrect | Unknown |
|----------|------------------:|--------------------:|-------:|------:|--------:|--------:|----------:|--------:|
| `verilog` | 198 | 213 | 242 | 0 | 0 | 365 | 0 | 46 |
| `uhdm` | 231 | 416 | 4 | 2 | 0 | 501 | 4 | 142 |
| `sv2v` | 205 | 364 | 83 | 1 | 0 | 492 | 1 | 76 |
| `slang` | 181 | 360 | 111 | 1 | 0 | 470 | 6 | 65 |

## Disagreements (11)

Tests where at least one frontend is **INCORRECT** while another is **CORRECT** — the highest-value triage list.

| Test | verilog | uhdm | sv2v | slang |
|------|---|---|---|---|
| `DotRange` | empty/CORRECT | empty/INCORRECT | empty/CORRECT | empty/CORRECT |
| `SizeOfUnsignedParameter` | empty/CORRECT | empty/CORRECT | empty/INCORRECT | empty/CORRECT |
| `SystemFunctions` | yes/CORRECT | yes/CORRECT | yes/CORRECT | yes/INCORRECT |
| `VarPassedTo2Submodules` | empty/CORRECT | empty/INCORRECT | empty/CORRECT | empty/CORRECT |
| `case_expr_extend` | empty/CORRECT | empty/CORRECT | empty/CORRECT | empty/INCORRECT |
| `const_fold_func` | yes/CORRECT | yes/CORRECT | yes/CORRECT | yes/INCORRECT |
| `counter_dual_xbranch` | yes/CORRECT | yes/CORRECT | yes/CORRECT | yes/INCORRECT |
| `hana_test_parse2synthtrans` | yes/CORRECT | yes/CORRECT | yes/CORRECT | empty/INCORRECT |
| `nested_full_case` | yes/CORRECT | yes/CORRECT | yes/CORRECT | yes/INCORRECT |
| `simple_memory` | yes/CORRECT | yes/INCORRECT | yes/CORRECT | yes/CORRECT |
| `sincos` | yes/CORRECT | yes/INCORRECT | yes/CORRECT | yes/CORRECT |

## Incorrect / crashed per frontend

- **uhdm** (6): `DotRange`, `EnumFirstInInitial`, `TaskReturn`, `VarPassedTo2Submodules`, `simple_memory`, `sincos`
- **sv2v** (2): `SizeOfUnsignedParameter`, `various_struct_access`
- **slang** (7): `SystemFunctions`, `case_expr_extend`, `const_fold_func`, `counter_dual_xbranch`, `hana_test_parse2synthtrans`, `nested_full_case`, `repwhile`
