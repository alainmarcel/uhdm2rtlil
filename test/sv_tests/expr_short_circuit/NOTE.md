CONVERTED, with the upstream claim partly out of reach.

Upstream's real subject is that `fun(c)` is NOT CALLED when `b` is already 1 --
it marks the function body with `$display(":assert: (False)")`.  A netlist has no
notion of a call: both arms of `||` are elaborated structurally and the optimiser
is free to keep or drop either.  So the conversion proves the VALUE of upstream's
expression over every input combination, which is what a netlist can show, and
records here that the short-circuit itself is a simulation-time property.
