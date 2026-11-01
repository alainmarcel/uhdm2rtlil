CONVERTED, with the all-x member's comparison out of reach of a proof.

`is_b = (x === b)` where `b` is `{32{1'bx}}` evaluates to 0 for a two-state input
on all three frontends (measured), but `sat -verify -prove` cannot carry the
claim: satgen does not model an x operand the way `eval` does, and the proof
finds a model where it differs.  Same limitation as the x/z literal tests.  So
`is_b` stays an OUTPUT -- the uhdm-vs-`read_verilog` netlist comparison compares
it exactly -- and only the two explicit members are proven.
