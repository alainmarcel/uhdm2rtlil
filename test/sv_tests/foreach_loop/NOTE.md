RATCHET -- `foreach` IS NOT UNROLLED in a combinational context.

read_uhdm warns `Cannot unroll foreach in comb context` and emits nothing for the
loop body, so all of the loop's work is lost:

* `foreach_loop` reads 0 visits and a sum of 0, where read_slang gives upstream's
  4 visits and 111+222+333+444 = 1110.
* `foreach_loop_synth` leaves the copied elements UNDRIVEN
  (`Wire test.\c0 [15] is used but has no driver`), where read_slang copies all
  four.

`read_verilog` cannot parse `foreach` (`syntax error, unexpected TOK_BEGIN`), so
read_slang is the oracle and the slang miter plus this proof are the gates.
Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt; both
entries must go in the commit that fixes it.
