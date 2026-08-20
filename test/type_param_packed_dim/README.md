# type_param_packed_dim

A chained type parameter carrying a **packed dimension**:

```systemverilog
parameter  type id_t      = logic [1:0],
parameter  type resp_id_t = id_t,                    // chained
localparam int  DEPTH     = (1 << $bits(resp_id_t)), // 1<<2 = 4
localparam type rt_t      = resp_id_t [DEPTH-1:0]    // 2*4 = 8 bits
```

`rt_i` came out **32 bits** instead of 8 (slang: 8).  This is CVA6
`hpdcache_mem_resp_demux`'s `rt_t = resp_id_t [RT_DEPTH-1:0]`.

It took three independent fixes, each of which alone left a plausible-looking
but wrong width — the intermediate results were 32 → 2 → 2 → 8.

## 1. Surelog: the declaration was compiled as an expression

`CompileHelper.cpp`, `compileParameterDeclaration`'s `paTYPE` branch.

`resp_id_t [DEPTH-1:0]` does **not** parse as a data type with a packed
dimension.  The grammar produces an *expression*:

```
Constant_primary
  ├─ StringConst  "resp_id_t"        <- element type
  └─ Constant_select
       └─ Constant_part_select_range
            └─ Constant_range        <- [DEPTH-1 : 0]
```

so `compileTypespec` sized it as a plain integer — 32 bits, regardless of the
element type.  The fix detects that shape and builds the
`packed_array_typespec` the declaration actually means, resolving the element
type from the same parameter list (as the chained-type-param fix does).  As
there, the element typespec is referenced **without re-parenting**.

## 2. `$bits` lookup needs the call's parent chain

`expression.cpp`.  `$bits(resp_id_t)` in a *parameter default* is evaluated
while the module's own parameters are being imported — at which point
`current_instance` is not yet set, so the by-name type-parameter lookup added
for `bits_of_type_param` found nothing.  It now falls back to walking the
call's `VpiParent()` chain to the enclosing `module_inst`.

## 3. Two const-fold gaps

`import_operation` only folds inside loop / function / generate / `dynports`
contexts, so two compile-time-constant expressions were left unfolded:

- **`module.cpp` `import_parameter`** — `DEPTH = 1 << $bits(...)` reported
  "non-constant value" and defaulted to **0**.  A parameter's value is
  constant by definition; fold it.
- **`module.cpp` `get_width_from_typespec`, packed_array_typespec ranges** —
  `[DEPTH-1:0]` is an *operation*, so the range silently contributed 1 and the
  array collapsed to a single element (width 2 = the element alone).  The same
  guard `import_port` already uses.

## Still open — unpacked array port of a type parameter

`hpdcache_mem_resp_demux` also has `output resp_t mem_resp_o [N-1:0]`, which
comes out 69 bits instead of 138 (one element instead of N).  That is an
*unpacked* dimension on a type-param port — a different shape from this test —
and is not fixed here.

## Checking

`read_verilog` cannot parse a chained type parameter, so this is a
**slang-miter-only** test (`test_slang_equiv.ys`).

```
wire width 2 input \id_i
wire width 8 input \rt_i     # was 32
```
