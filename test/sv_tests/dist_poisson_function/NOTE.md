NOT SYNTHESIZABLE -- classified, not converted.

Class: random distribution
A random distribution is a simulation service and is not deterministic, so a netlist cannot carry its answer.

Upstream evidence:
    	integer seed = 1234;
    	$display("%d", $dist_poisson(seed, 100));
    end

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
