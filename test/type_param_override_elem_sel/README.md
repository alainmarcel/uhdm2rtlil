# type_param_override_elem_sel

A `parameter type` that is **overridden at the instantiation**, used to build a
packed-array type, then dynamically indexed:

```systemverilog
module child #(
    parameter  type id_t  = logic,                 // DEFAULT: 1 bit
    localparam int  DEPTH = (1 << $bits(id_t)),
    localparam type rt_t  = id_t [DEPTH-1:0],
    localparam type sel_t = logic [0:0]
) (input rt_t rt_i, input id_t id_i, output sel_t sel_o);
  assign sel_o = rt_i[int'(id_i)];
endmodule

child #(.id_t(logic [1:0])) u (...);               // OVERRIDE: 2-bit element
```

`rt_i[int'(id_i)]` came out as an **unscaled bit select** — `$shiftx` with
`Y_WIDTH 1` reading bit `id` instead of the 2-bit element at `id*2`.  Correct
only for `id == 0`; wrong for the other three.

This is CVA6 `hpdcache_mem_resp_demux`'s routing select
(`mem_resp_rt_i[int'(mem_resp_id_i)]`), which sent responses to the wrong
output port on ~35% of cycles.

## Two bugs, both required

**1. Surelog — the element was resolved from the DECLARATION DEFAULT.**
`compileParameterDeclaration` builds `rt_t`'s `packed_array_typespec` at
definition time, where `id_t` is still its default `logic` (1 bit).  `rt_t` is
a *localparam* type, so nothing re-resolved it per instance and the element
stayed 1 bit even though the instance binds 2.

The element reference now records the source type's name, and
`ElaborationStep::elabTypeParameter_` re-binds it against the instance
(`bindTypespec`), rebuilding the typespec when the binding differs.

**2. uhdm2rtlil — `import_bit_select` never read that typespec.**
Its element-width detection consulted only `logic_net` / `logic_var`, but a
signal declared with a packed-array *type* elaborates to a
`packed_array_var` / `packed_array_net`.  So even with the corrected UHDM the
width stayed 1.  Both forms are now consulted.

## Why it took a bisect

Four narrower repros were built first and **all PROVED**, so each hypothesis
was rejected in turn:

| repro | result |
|---|---|
| `rt[int'(id)]` on a type-param packed array | PROVEN — not the bug |
| pack/unpack generate loop (packed elem -> unpacked port elem) | PROVEN — not the bug |
| assignment target narrower than the element | PROVEN — not the bug |
| chained element type (`id_t = base_id_t`) | PROVEN — not the bug |

The missing ingredient in every one was the **override at the instantiation**:
with defaults only, the definition-time and bound types coincide and the bug is
invisible.  That is also why `hpdcache_demux` and `hpdcache_mux` prove
individually while their composition failed.

## Checking

`read_verilog` cannot parse the type-parameter override shape, so this is a
**slang-miter-only** test (`test_slang_equiv.ys`).  It FAILS (miter finds a
counterexample) without either fix.
