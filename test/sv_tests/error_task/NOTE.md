NOT SYNTHESIZABLE -- classified, not converted.

Class: severity task
`$error` reports a simulation-time message with a severity.  It is not an
assertion with a condition, so there is nothing for a netlist to carry and
nothing a proof can read.  (Severity tasks reached from a concurrent or immediate
ASSERTION do become `$check` cells -- see the sva_* tests -- but a bare `$error`
in an `initial` block does not.)

Upstream evidence:

    	$error("error");
