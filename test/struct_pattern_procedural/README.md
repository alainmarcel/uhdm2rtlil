# struct_pattern_procedural

Assignment patterns on a struct inside an `always_comb`:

```systemverilog
r = '{default: DONT_CARE};                              // DONT_CARE = 1'b1
r = '{sign: 1'b0, exponent: '1, mantissa: 2**(23-1)};
```

on `fp_t {sign; exponent[7:0]; mantissa[22:0]}`. Both were wrong:

| pattern | expected | got |
|---|---|---|
| `'{default: 1'b1}` | `0x80800001` | `0xffffffff` |
| `'{sign:0, exponent:'1, mantissa:2**22}` | `0x7fc00000` | `0x00400000` |

## Cause

Both pattern handlers need the **target** struct typespec, and both looked for
it in only two places: the operation's own typespec, and — for the `default:`
form — a parent `param_assign`. An assignment-pattern operation carries no
typespec of its own, and in a procedural context its parent is an `assignment`,
not a `param_assign`, so neither source produced anything.

The two handlers then failed differently, which is why one over-filled and the
other under-filled:

- **`'{default: V}`** fell through to the packed-**vector** branch, which fills
  every *bit* with V. That is right for `logic [N-1:0]`, but for a struct the
  value goes to each *member*, converted to that member's width:
  `{1'b1, 8'h01, 23'h1}` = `0x80800001`, not all-ones. Note this is invisible
  when every member is 1 bit wide — `status_t` gives `5'b11111` either way,
  which is why the DUT covers both struct shapes.
- **named fields** fell back to guessing each field's width as
  `context_width / field_count` = 32/3, which is not a whole number, so the
  guess came out 0 and no field was resized. The resulting concat was *wider*
  than the target and the caller truncated it — discarding the top fields,
  `sign` and `exponent`, and leaving only the mantissa.

## Fix

One shared helper, `assignment_lhs_typespec()`, recovers the target type from
the parent `assignment`/`cont_assign`'s LHS (descending a `ref_obj` to its
declaration). Both handlers consult it when the existing sources come up empty.

## Coverage

| arm | checks |
|---|---|
| `'{default: 1'b1}` on `fp_t` | mixed member widths — the over-fill case |
| `'{default: 1'b1}` on `status_t` | all-1-bit members: same result either way, so it guards against over-correcting |
| `'{sign, exponent: '1, mantissa}` | named fields, including an unsized fill literal as one field |
| `'{sign, exponent: '0, mantissa: 23'd5}` | named fields, all sized literals |
| `'{nv:..., dz:..., ...}` | named fields on the all-1-bit struct |
| `'0` default arm | control |

## CVA6

`fpnew_noncomp` uses the first form for its don't-care results
(`result_d = '{default: DONT_CARE}`) and the second for NaN-box
canonicalization (`sgnj_result = '{sign: 1'b0, exponent: '1, mantissa: ...}`).
Together with the `packed_struct_array_net_elem` fix, the module's Verilator
divergence went 2972/3000 → 2784 → 88 → **0**, and it is now SAT-proven.

## Checking

The miter against `read_slang` PROVES it.
