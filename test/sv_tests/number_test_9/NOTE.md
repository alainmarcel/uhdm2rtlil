RATCHET -- an UNSIGNED BINARY literal is SIGN-EXTENDED into a wider signed parameter.

`parameter int foo = 1'b1;` must be 1: a sized literal without `s` is UNSIGNED, so
it zero-extends into the 32-bit `int`.  read_verilog and read_slang both give 1;
read_uhdm gives **all ones** (-1).

Measured 2026-11-01, four literals into `int` in one file:

| literal | read_verilog | read_slang | read_uhdm |
|---|---|---|---|
| `1'b1`     | 1   | 1   | **-1** |
| `4'b1111`  | 15  | 15  | **-1** |
| `8'hFF`    | 255 | 255 | 255 (correct) |
| `4'sb1111` | -1  | -1  | -1  (correct) |

So it is specific to the BINARY base: the hex form of the same bit pattern is
zero-extended correctly, and the explicitly SIGNED binary form is sign-extended
correctly.  Only an unsigned `'b` literal whose MSB is 1 takes the wrong path.

Likely the same code as the documented "Surelog Const-Folded Function Results:
Signed BIN Constants" handling in CLAUDE.md, which sign-extends a
`vpiBinaryConst` when its typespec says signed -- here the TARGET is signed but
the LITERAL is not, and the literal's own signedness is what decides.

The sibling tests pin the boundary and must keep passing: `number_test_6`/`_7`/
`_8` (`1'b0` and spellings, value 0 so extension is invisible), `number_test_15`
(`4'sb1111`, correctly -1), `number_test_61`..`_68` (hex forms, correct).

Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt; both
entries must go in the commit that fixes it.

**The x/z literals show the same defect**, measured at the same time -- read_uhdm
extends the x or z bit across the whole width where read_verilog zero-extends:

| literal | read_verilog | read_uhdm |
|---|---|---|
| `1'bx`     | `0000…000x` | all don't-care (32) |
| `4'bxxxx`  | `0000…xxxx` | all-x (32) |
| `1'bz`     | `0000…000z` | all-z (32) |
| `4'bzzzz`  | `0000…zzzz` | all-z (32) |

So this is ONE defect with six witnesses: `number_test_9` (all-ones),
`number_test_13` (all-x, the other entry in the ratchet lists) and
`number_test_10`/`_11`/`_12`/`_14`, whose own gates cannot see it -- SAT takes no
x constant, read_slang normalises x/z differently, and the netlist has zero gates
so the workflow comparison is vacuous.  Each of those four carries the
measurement in its own NOTE.md.  Fixing the extension should change all six.
