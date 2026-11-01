NOT SYNTHESIZABLE -- classified, not converted.

Class: simulation control task
`$printtimescale`, `$timeformat`, `$realtime`, `$stime` and `$time` read or report SIMULATION TIME; a netlist has no clock of that kind.

Upstream evidence:
    $printtimescale / $timeformat / $realtime / $stime / $time

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
