FIXED 2026-11-02 (was a RATCHET) -- the constant real-valued system functions
are folded.

read_uhdm used to implement only `$clog2`, `$ceil` and `$floor` of the constant
system functions; for this one it warned `Unhandled system function call` and
returned the FIRST ARGUMENT unchanged, so the netlist silently carried the operand
where the function's value belonged.  A constant real-valued expression tree --
the real math functions, real literals, + - * / and `int'()` casts over them --
is now evaluated in double precision at its OUTERMOST operation and rounded once
(`int'($pow(2.25, 2) * 10000)` is 50625, not 5 * 10000); `$countones`,
`$countbits`, `$onehot`, `$onehot0`, `$isunknown` and `$isunbounded` have RTLIL
or constant implementations.  `read_verilog` computed all of them and was the
oracle while the ratchet stood.
