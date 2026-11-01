FIXED 2026-11-01 -- an UNSIGNED BINARY literal was SIGN-EXTENDED into a wider
signed parameter.  Kept as the record of what the ratchet proved; the test now
proves `o == 1` against read_verilog AND read_slang, and the sibling tests pin
the boundary (`number_test_6`/`_7`/`_8` zero literals, `number_test_15` the
signed `4'sb1111` = -1, `number_test_61`..`_68` the hex forms).

`parameter int foo = 1'b1;` must be 1: a sized literal without `s` is UNSIGNED, so
it zero-extends into the 32-bit `int`.  read_uhdm gave **all ones** (-1):

| literal | read_verilog | read_slang | read_uhdm BEFORE | after |
|---|---|---|---|---|
| `1'b1`     | 1   | 1   | **-1** | 1 |
| `4'b1111`  | 15  | 15  | **-1** | 15 |
| `8'hFF`    | 255 | 255 | 255    | 255 |
| `4'sb1111` | -1  | -1  | -1     | -1 |
| `1'bx`     | `0000…000x` | - | all don't-care | `0000…000x` |
| `4'bxxxx`  | `0000…xxxx` | - | all-x          | `0000…xxxx` |
| `1'bz`     | `0000…000z` | - | all-z          | `0000…000z` |

It was TWO defects, neither where the first measurement guessed (import_constant):

1. **Surelog `CompileHelper::adjustSize`** decided "the constant is signed" from
   the `int_typespec` attached to it.  A `'s` literal does carry one -- but the
   elaborator also stamps the PARAMETER's declared type onto an unsigned literal
   after the first pass, so the second pass read `int` as the literal's own
   signedness and two's-complemented `2'b11` into `INT:-1`.  The elaborated
   `assign o = foo` therefore reached the reader as a folded `constant INT:-1`
   (the definition view still held the `ref_obj`).  Fixed upstream: the
   literal's decompile sigil decides while it is still a literal.
2. **The reader**, for the literals Surelog leaves narrow (`BIN:xxxx` size 4
   with an `int` typespec, `BIN:11` size 2 with `byte`, `BIN:X` size 1):
   `is_expr_signed` fell back to the stamped typespec for a based literal
   without `'s` (sign/x-extension), and `import_continuous_assign` replicated
   ANY 1-bit constant to the LHS width (meant for `'1` fills, which already
   arrive context-sized).  A third, smaller one: Surelog spells a folded x digit
   `BIN:X` and `Const::from_string` knows only lower case, so it read as `-`.

Found converting the 55 `number_test_*` cases (each is `parameter <type> foo =
<literal>;` plus an EMPTY module upstream, so the literal's value reached
nothing).  A 22-variant probe (`parameter <T> foo = <lit>; assign o = foo;`
against read_verilog) localised the split.
