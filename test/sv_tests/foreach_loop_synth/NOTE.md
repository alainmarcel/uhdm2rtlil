FIXED 2026-11-02 (was a RATCHET) -- `foreach` over a MODULE-LEVEL array was
not unrolled in a combinational context: the array's unpacked dimension lives on
the array_var object, not on its (bare array_typespec) type, and the bound
finder read only the type.  Before the fix read_uhdm warned `Cannot unroll
foreach in comb context` and emitted nothing for the loop body, so all of the
loop's work was lost:

* `foreach_loop` reads 0 visits and a sum of 0, where read_slang gives upstream's
  4 visits and 111+222+333+444 = 1110.
* `foreach_loop_synth` leaves the copied elements UNDRIVEN
  (`Wire test.\c0 [15] is used but has no driver`), where read_slang copies all
  four.

`read_verilog` cannot parse `foreach` (`syntax error, unexpected TOK_BEGIN`), so
read_slang is the oracle and the slang miter plus this proof are the gates.
