# dyn_field_select

A struct member indexed by a **runtime** value, reached through a run of dynamic
array indices:

```systemverilog
assign taken_o = tbl[row_i][col_i].sat[sel_i][1];
```

The importer gave up on the dynamic *field* index and dropped the **whole
continuous assign**, leaving that output bit undriven.

## Cause

`import_hier_path`'s N-index branch shifts a slice out of the flat wire at
`field_offset + Σ (idx_k − low_k)·stride_k`. It handled dynamic indices in the
leading **index run**, but a dynamic index on the **field itself** hit one of two
explicit bail-outs — `field_ok = false` in the trailing-bit_select case, and
`// dynamic — not yet` in the multi-dim `var_select` case. Either one failed the
whole access, so the assign was never emitted:

```
Warning: UHDM: Could not resolve struct member access
         'bht_q[index][i].saturation_counter[i][1]'
```

## Fix

A dynamic field index now contributes one more term to the same shiftx offset,
with its stride taken from the field's outer packed dim and the result narrowed
to one element. A later dim can still fold a constant on top, because
`field_offset` stays additive. Two dynamic dims on one field are still rejected.

## Coverage

| output | checks |
|---|---|
| `taken_o` | dynamic field index **plus** a trailing constant bit — the failing case |
| `cnt_o` | dynamic field index selecting a whole element |
| `valid_o` | a sibling field with no select (control — this one always worked, which is what made the bug visible as *one* undriven bit) |
| `const_o` | the same field with a **constant** index (control — guards against the dynamic path stealing the constant one) |

## Gotcha

`row_i`/`col_i` are **1 bit** deliberately. `tbl` is 2×2, so wider index inputs
would let the miter pick an out-of-range element, where UHDM/slang clamp per LRM
and the comparison legitimately differs — a false failure that has nothing to do
with this fix.

## CVA6

`bht2lvl`: `bht_prediction_o[i].taken` was undriven while its `.valid` sibling
was fine, so the output read 0 on **every** cycle. Verilator adjudication goes
**2000/2000 → 20/2000**, with the first divergence moving from cycle 0 to 293.
The module is **still a counterexample** — a second, independent defect remains
in the upper element (`rtl=5 uhdm=1`, i.e. bit 2 = element 1's `taken`).
