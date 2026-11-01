CONVERTED, and gated on the netlist SHAPE plus read_verilog.

A miter is not a gate for an assertion: `test_slang_equiv.ys` would read with
`--ignore-assertions` (the checks would otherwise become miter asserts of their
own), so read_slang emits no `$check` by construction.  What the test claims is
that the assertion is not DROPPED -- at least one `$check` -- which read_verilog
also produces, plus the surrounding logic, which the uhdm-vs-verilog comparison
covers.  The cell is counted and then DELETED before the value proof, because a
`$check` has no SAT model.
