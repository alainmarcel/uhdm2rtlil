RATCHET -- `repeat` IS NOT UNROLLED in a combinational context.

With a CONSTANT count (`repeat(128)`), read_verilog unrolls the loop and the
accumulator reads 128.  read_uhdm warns
`Unsupported statement type in comb context` and emits nothing, so the
accumulator stays 0.  Same family as the `foreach` gap in `foreach_loop`.

Upstream's own count is a VARIABLE, which NO frontend unrolls -- read_verilog
says `Repeat loops outside must have constant repetition count` -- so the
conversion uses upstream's own 128 as a literal, which is the synthesizable form
of the same loop.  `read_slang` refuses `repeat` outright
(`unsupported language feature`), so read_verilog is the oracle and there is no
slang miter.

Listed in structural_expected_fail.txt; remove it there in the commit that
unrolls `repeat`.
