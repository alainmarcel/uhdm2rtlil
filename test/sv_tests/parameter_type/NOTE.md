FIXED 2026-11-02 (was a RATCHET) -- a `real` was measured as 32 bits, not 64:
get_width_from_typespec had no case for real_typespec / short_real_typespec and
fell through to the 32-bit default.

`$bits(T)` where `T` is a type parameter defaulting to `real` must be 64.
read_slang gives 64; read_uhdm used to give **32**.  Measured alongside it in the same
file, `$bits(real)` written directly gives read_slang 64 and read_uhdm **0**,
with `Warning: Empty argument in sys_func_call $bits` and
`Unsupported expression type` -- so the type keyword is not accepted as an
argument at all, and the type-parameter path merely guesses a 32-bit width.

`read_verilog` cannot parse a `type` parameter (`syntax error, unexpected
TOK_ID`), so read_slang is the oracle and there is no uhdm-vs-verilog comparison.
A miter would be the natural gate but read_slang's own netlist for this module is
a constant, so the structural proof carries it.
