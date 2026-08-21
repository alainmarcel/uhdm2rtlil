# packed_struct_array_net_elem

A **net**-declared packed array of a named struct typedef, indexed by a
constant:

```systemverilog
fpnew_pkg::fp_info_t [1:0] info_q;
assign info_a = info_q[0];      // must be info_q[7:0], the whole element
```

`info_q[0]` selected a single **bit**, which was then zero-extended to the
struct's width:

```
connect \info_a { 7'0000000 \info_q [0] }     # wrong
connect \info_a \info_q [7:0]                 # right
```

so every field of the struct read as 0.

## Cause

`import_bit_select` derives the element width for a packed array of structs by
finding the elaborated array object. That search accepted only
`packed_array_var` — the **variable** form — and looked for it exclusively in
`wire_map`. A `logic`-net declaration of the same shape elaborates to a
`packed_array_**net**`, which both the cast and the search missed, so
`packed_elem_w` stayed 1 and the constant-index path extracted one bit.

The dynamic-index path further down already handled both forms; only the
constant-index path was short.

## Fix

Accept `packed_array_net` alongside `packed_array_var`, and read the
declaration off the bit_select's own `Actual_group()` before falling back to
searching `wire_map` — the object is right there on the node.

## Coverage

| expression | checks |
|---|---|
| `info_q[0]` | the failing case — element 0 |
| `info_q[1]` | a non-zero element index (guards against an unscaled offset) |
| `info_q[sel_i]` | dynamic index — the path that already worked, kept as a control |
| `a.is_boxed` | a field of a constant-indexed element, end to end |

## CVA6

This is `fpnew_noncomp`'s `info_a = info_q[0]` / `info_b = info_q[1]`, the
outputs of its `fpnew_classifier` instance. With every `info_a.is_*` reading 0,
the classify chain fell through to its default and `class_mask_o` returned QNAN
for every input; `status_o` and `extension_bit_o` were wrong too. Fixing this
took the module's Verilator divergence from 2972/3000 to 2784/3000 — the
remaining gap was a separate defect (see `struct_pattern_procedural`).

## Checking

The miter against `read_slang` PROVES it.
