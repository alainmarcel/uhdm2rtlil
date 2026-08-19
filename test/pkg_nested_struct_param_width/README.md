# pkg_nested_struct_param_width

A width expression that reads a **nested** field of a package `localparam`
struct:

```systemverilog
localparam user_cfg_t UCFG = mku();          // struct built by a function
localparam cfg_t      CFG  = build(UCFG);    // nested: cfg_t.u is a user_cfg_t

typedef logic [CFG.u.sidWidth-1:0] sid_t;    // TWO levels -- was broken
typedef logic [CFG.derived-1:0]    data_t;   // ONE level  -- always worked
```

`sid_i` came out as `wire width 0 upto offset -1` (slang: 3 bits), so every
downstream connection collapsed.  `data_i` was correct at 64 bits.

## Root cause — UHDM `ExprEval::hierarchicalSelector`

Not a uhdm2rtlil bug and not a folding failure: **Surelog baked a broken range
into the elaborated UHDM**, and the frontend faithfully imported it.

In the elaborated model `pk::data_t`'s left range is a folded `constant`, but
`pk::sid_t`'s is still an `operation(vpiSubOp)` whose first operand is a
`struct_var` — the *whole* `user_cfg_t` value substituted where the scalar
`sidWidth` belonged.  `read_uhdm` cannot evaluate that (`Unsupported expression
type: struct_var`), reads it as 0, and computes `[0-1 : 0]` → width 0.

The substitution comes from `hierarchicalSelector`'s `struct_var` branch: on a
`ReturnType::VALUE` walk it returned the matched member's value
**unconditionally**, ignoring `lastElem` and never recursing into the remaining
path elements.  So `CFG.u.sidWidth` stopped at `u` and yielded the nested
struct.  One-level paths were unaffected because their only member *is* the
last element — exactly the observed split between `sid_t` and `data_t`.

The `struct_typespec` branch a few lines below already had the correct
`if (lastElem) return res; else recurse` shape; the fix gives the `struct_var`
branch (and the identical `io_decl` branch) the same walk.

Fixed in `third_party/Surelog/third_party/UHDM/templates/ExprEval.cpp`.
Requires re-running Surelog to re-elaborate — the bad range is stored *in* the
`.uhdm` file, so an existing `slpp_all/surelog.uhdm` keeps reproducing it.

## Checking

`read_verilog` cannot parse function-built struct localparams, so this is a
**slang-miter-only** test (`test_slang_equiv.ys`), like `def_ctx_struct_param`.

```
wire width 3  input 2 \sid_i      # was: width 0 upto offset -1
wire width 64 input 3 \data_i
```
