CONVERTED, but the directive's EFFECT is not observable here.

`unconnected_drive pull1` should pull an instance's unconnected input port to 1.
None of the three frontends implements that: a `child u (.p(a), .q(), .o(o));`
inside the region leaves `q` undriven under `read_verilog`, `read_slang` AND
`read_uhdm` alike (measured 2026-10-31), so a test that proved the pull would
fail on all three rather than on ours.  The conversion therefore claims only
what is true -- the directive is accepted and does not perturb compilation --
and this file records what a stronger version would need.  Not a reader defect
and not a gap in our frontend specifically.

`read_verilog` cannot read it at all: `ERROR: Unimplemented compiler directive
or undefined macro `unconnected_drive`.  The test is therefore UHDM-only against
the golden frontend, and `read_slang` plus the structural proof are its gates.
