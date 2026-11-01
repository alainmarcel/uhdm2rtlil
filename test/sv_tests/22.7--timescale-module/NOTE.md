CONVERTED, but the directive's own effect is not observable here.

A `timescale sets the simulation time unit and precision.  That is a
simulation-time property: no netlist, and no formal check over one, can show it,
so a converted test cannot prove the directive took effect -- only that it is
accepted and does not perturb compilation.  What this test DOES observe is the
real-valued `parameter d = 1.55` surviving elaboration with its value, which is
what upstream's `#d` delays consumed it for.  Not a reader defect.
