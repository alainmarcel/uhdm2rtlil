RATCHET -- `$isunbounded` is not implemented.

read_uhdm warns `Unhandled system function call: $isunbounded` and returns its
operand: 1 for the literal (should be 0) and the `$` for the parameter.  Neither
read_verilog (`Can't resolve function name`) nor read_slang implements it either,
so there is no oracle beyond the LRM: `$isunbounded(1)` is 0 and `$isunbounded`
of a `$`-valued parameter is 1.  Listed in structural_expected_fail.txt.
