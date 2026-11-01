CONVERTED, with the assertion's own effect out of reach.

Measured 2026-10-31: this assertion form reaches a netlist on NONE of the three
frontends -- read_uhdm and read_slang emit no `$check` for it, and read_verilog
cannot even parse it (`Can't resolve task name` / a syntax error).  So a test that asserted the cell would fail on
all three rather than on ours, and this conversion claims only what is true: the
form is ACCEPTED and does not perturb the surrounding logic, which the proof
below pins.  `initial assert`, `initial cover` and `initial assume` DO reach a
netlist -- see assert_test, cover_test and assume_test -- so this is specific to
the deferred / `final` / concurrent-property forms.
