CONVERTED, with the assertion's own effect out of reach.

Measured 2026-10-31: a concurrent `assume property` reaches a netlist on NONE of
the three frontends -- read_uhdm and read_slang emit no `$check` for it, and
read_verilog cannot parse it at all.  A test that asserted the cell would fail on
all three rather than on ours, so this claims only what is true: the form is
accepted and does not perturb the logic beside it.  The IMMEDIATE forms do reach
a netlist (assert_test, cover_test, assume_test).
