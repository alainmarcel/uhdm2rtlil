# struct_param_pattern_packing

A struct **parameter** initialised by a named-field assignment pattern:

```systemverilog
localparam cfg_t LIT = '{n: 3, base: 64'h1000};   // {int unsigned, logic[63:0]}
```

was packed as `{48'd3, 48'h1000}` instead of `{32'd3, 64'h1000}`, so every field
read at the wrong offset. Decoding the 96-bit constant showed it directly:

```
before:  n = 0            base = 0x3000000001000
after:   n = 3            base = 0x1000
```

## Cause

Two things had to be wrong at once, which is why it survived the round-27 fix:

1. **The target typespec was not found.** A parameter initialiser is a
   `param_assign`. The `'{default:}` handler already had a `param_assign` case,
   but the named-field handler's `assignment_lhs_typespec()` covered only
   `assignment` and `cont_assign`. Added `param_assign`, taking the typespec from
   a `parameter` LHS.
2. **The fields arrive untagged.** Even with the struct typespec in hand, the
   per-field width lookup keys off `tagged_pattern` — and on an **elaborated**
   parameter Surelog strips the tags and emits **bare exprs in declaration
   order**. So the lookup never ran and every field kept the
   `context_width / field_count` guess: 96/2 = 48.

Fix (2) sizes a bare operand positionally from the struct's members, guarded on
the operand count matching the member count.

## Coverage

| output | checks |
|---|---|
| `o_n`, `o_base` | the two unequal-width members of a 2-field struct |
| `o_a`, `o_b`, `o_c` | a 3-field struct with three different widths (8/16/1), where `ctx/count` is not even a whole number |
| `o_fn` | the struct param passed through a **function argument** — the shape that first exposed this, since a mis-packed field made `if (C.n != 0)` constant-false and collapsed the call |

## Checking

The miter against `read_slang` PROVES it.

## Scope — what this does NOT fix

Only parameters whose value is a **literal pattern**. A parameter built by a
**function** that assigns members and returns the struct —

```systemverilog
parameter cfg_t CFG = build_config(...);
```

— still folds to all-zeros, because that function cannot be evaluated
(`evalFunc` returns a value-less `struct_var`). `test/struct_param_func_arg`
remains a known-fail for that shape, and CVA6 `pmp_data_if` is unchanged at
377/2000 because its `CVA6Cfg` comes from `build_config()`.
