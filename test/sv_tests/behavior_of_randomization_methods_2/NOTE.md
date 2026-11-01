NOT SYNTHESIZABLE -- classified, not converted.

Class: constrained randomization
Constrained randomization is a simulation-time service: a solver call has no netlist form.

Upstream evidence:
        /* Create infeasible constraint */
        constraint c { b == 0 && b > 0; }
    endclass

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
