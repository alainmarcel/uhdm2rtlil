# fill_literal_compare

An unsized fill literal (`'0`, `'1`, `'x`, `'z`) used as a **comparison
operand**:

```systemverilog
assign ne_ones_o = (x_i != '1);   // x_i is 5 bits
```

A fill literal has no width of its own — it is context-determined, so here it
must replicate to the width of the other operand (`5'b11111`). It was imported
as a **single bit**, so the comparison was against `5'b00001`: true for every
`x_i` except 1, instead of true for every `x_i` except 31.

## Cause

`import_constant` returns a 1-bit `SigSpec` for a fill literal (`VpiSize()`
is `-1`), which is correct — the width has to come from context. Assignment
sites already handle this (see the `'0`/`'1` notes in CLAUDE.md), but the
operator path did not: the per-operator sizing below the switch equalises the
two operands by zero-extending the narrower one, which turns `'1` into
`5'b00001` rather than `5'b11111`.

## Fix

Before the operator switch, for the comparison operators
(`== != === !== ==? !=? < <= > >=`), an operand that is a fill literal
(`VpiSize() == -1`) and still one bit wide is replicated to the width of the
other operand. Only comparisons are touched — arithmetic and the shift
operators have different context rules.

## Coverage

| expression | checks |
|---|---|
| `x_i != '1` | the failing case |
| `x_i == '1` | the same literal on the equality operator |
| `x_i == '0` | `'0` replicates too (this one happens to agree at 1 bit, so it guards against over-replication) |
| `w_i == '1` | a 64-bit operand, past the single-word boundary |
| `x_i <  '1` | a relational operator, not just equality |

## Checking

The miter against `read_slang` PROVES it. Note `read_verilog` gets this right
already, so this is a case where the UHDM frontend was alone in being wrong.

## Not the fpnew_classifier fix

This was found while triaging CVA6 `fpnew_classifier`, whose classifications
are all `exponent == '0` / `exponent == '1` comparisons — but that module's
netlist shows the literal **already** correctly replicated
(`B_WIDTH 8, connect \B 8'11111111`), and re-adjudicating after this fix gives
byte-identical numbers (uhdm_vs_rtl 1497/3000). The repro that led here was
built by hand and turned out to be unrepresentative of the real module: it hit
this separate, genuine bug instead. `fpnew_classifier` remains a
counterexample; this fix stands on its own.
