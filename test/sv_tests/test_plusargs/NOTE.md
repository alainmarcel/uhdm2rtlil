NOT SYNTHESIZABLE -- classified, not converted.

Class: simulation control task
`$test$plusargs` / `$value$plusargs` read the simulator's COMMAND LINE.

Upstream evidence:
    $test$plusargs("...") / $value$plusargs("...", v)

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
