# struct_member_expr_index

A struct member indexed by a compile-time **expression** instead of a literal:

```systemverilog
assign man_msb_o = value.mantissa[MAN_BITS-1];   // MAN_BITS = 23
```

selected bit **23** instead of bit **22**.

## Cause

`import_hier_path` resolves a struct access from the hier_path's *textual*
name. Surelog does not fold the index into the text, so the member arrives as

```
Detected struct member access: base='value', member='mantissa[23 - 1]'
Calculated struct member 'value.mantissa[23 - 1]' offset=23, width=1
```

`calculate_struct_member_offset` parses the bracket with a plain integer scan,
which reads `23` and stops at the space — silently dropping the `- 1`. The
trailing-range splitter added for `struct_array_member_partsel` does not catch
it either: its three `sscanf` patterns (`%d+:%d`, `%d-:%d`, `%d:%d`) all need a
`:`, and this is a single index.

## Fix

The hier_path's trailing `bit_select` carries the index as a real expression
(here `operation(vpiSubOp, 23, 1)`), so it is folded through `import_expression`
and the bracket text is rewritten with the result before the resolver runs.

Only the **text** is rewritten. Whether an index means a *bit* or an *array
element* remains the resolver's decision — `rdata[0]` on a `logic [1:0][63:0]`
member must still yield the whole 64-bit element, which is why the fold does not
short-circuit to a 1-bit slice. `elem_o` / `elem_expr_o` in the DUT cover that.

## Coverage

| expression | checks |
|---|---|
| `value.mantissa[MAN_BITS-1]` | the failing case |
| `value.mantissa[22]` | the same bit as a literal — the two must agree |
| `value.mantissa[MAN_BITS-23]` | folds to 0, the low end |
| `value.exponent[EXP_BITS-1]` | a different, non-final member |
| `av.pair[1]` | array member, literal index — whole element |
| `av.pair[MAN_BITS-22]` | array member, expression index — must stay a whole element, not become 1 bit |

## CVA6

This is `fpnew_classifier`'s
`is_signalling = is_boxed && is_nan && (value.mantissa[MAN_BITS-1] == 1'b0)`.
Reading bit 23 (the exponent's LSB) instead of the mantissa's MSB inverted the
signalling/quiet decision for every NaN. Counterexample
`operands_i=0x7f800001, is_boxed_i=1` (a signalling NaN) gave `info_o=0x0b`
against slang's `0x0d`.

## Checking

The miter against `read_slang` PROVES it, so each select lands on the same bits
slang selects. `read_verilog` also handles this shape and its netlist is
identical to the UHDM one, so the workflow comparison covers it too — the DUT is
pure wiring, and every connect is checkable by eye:

```
connect \man_msb_o     \word_i [22]      # was [23] before the fix
connect \man_msb_lit_o \word_i [22]
connect \man_lsb_o     \word_i [0]
connect \exp_msb_o     \word_i [30]
connect \elem_o        \arr_i [19:12]    # 8-bit ELEMENT, not one bit
connect \elem_expr_o   \arr_i [19:12]
```
