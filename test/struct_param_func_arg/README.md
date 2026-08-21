# struct_param_func_arg

**Known-failing reproducer — an unfixed UHDM bug, not a passing test.**

A struct **parameter** passed as a **function argument**, with a field read from
the formal inside the function:

```systemverilog
function automatic logic in_region(cfg_t C, logic [63:0] a);
  if (C.n != 0) return (a >= C.base);
  else          return 1'b1;
endfunction

assign o_fn     = p::in_region(CFG, a_i);   // CFG.n == 3
assign o_direct = CFG.n;                    // reads 3 correctly
```

| output | uhdm | slang |
|---|---|---|
| `o_direct` | `32'd3` | `32'd3` — agree |
| `o_fn` | `1'h1` (constant) | `a_i >= 13'h1000` (real logic) |

`C.n` reads **0** inside the function, so `if (C.n != 0)` becomes constant-false,
only the `else` arm survives, and the whole call collapses to `1'b1`.

## What this is NOT

Three things are ruled out by construction, which is why the DUT carries
`o_direct` alongside `o_fn`:

- **Not** the parked `evalFunc` value-less `struct_var` defect. That one makes
  the struct's value unavailable entirely; here `o_direct = 32'd3` proves the
  parameter folds correctly. The failure is specific to reading the field
  through a function's formal.
- **Not** Surelog pre-folding the call. The UHDM carries a proper `func_call`
  node with both arguments (`CFG` and `a_i`), so the collapse happens on our
  side.
- **Not** the `all_const` const-eval guard. That guard is present and correct —
  `a_i` is a wire, so the call is *inlined* rather than constant-evaluated. The
  constant appears because the inlined body's guard folds.

## The actual mechanism (decoded)

The field does not "read as 0" because anything is missing — the struct
parameter's **constant is mis-packed**. Decoding the 96-bit value bound to the
formal:

```
n    = 0                      (bits 95:64)
base = 0x3000000001000        (bits 63:0)
```

That is `{48'd3, 48'h1000}`: each named field was sized to
`context_width / field_count` = 96/2 = **48** bits, instead of the members' real
widths (32 and 64). The `3` therefore sits at bits 49:48 and `n`'s own slice
reads 0.

This is the same defect as the round-27 named-field sizing bug, reached through a
**parameter initialiser** rather than a procedural assignment. Everything else on
the path is already correct and was verified by probe:

- the argument is collected fully-const at the call site (`size=96 const=1`);
- `module->parameter_default_values` holds that same 96-bit constant;
- `import_hier_path` resolves `C.n` to the right slice (`off=64 w=32`);
- `func_mapping` / the io_decl wire binding pass the value through unchanged.

So the constant is wrong before any of that runs — it is built wrong where the
assignment pattern is imported.

## Partially addressed

The **packing** half is now fixed (see `test/struct_param_pattern_packing`): a
parameter initialised by a *literal* pattern packs its fields correctly. Two
changes were needed — `param_assign` in `assignment_lhs_typespec()`, and
positional sizing for the **bare, untagged** operands Surelog emits for an
elaborated parameter.

**This test still fails**, because its `CFG` comes from `p::build()` — a function
that assigns members and returns the struct. That folds to all-zeros, not
mis-packed, and is the parked `evalFunc` value-less `struct_var` defect. CVA6
`pmp_data_if` is in the same category (`CVA6Cfg = build_config(...)`) and remains
at 377/2000.

So this reproducer now isolates exactly one thing: the function-built struct
parameter. Fixing it means fixing `evalFunc`.
