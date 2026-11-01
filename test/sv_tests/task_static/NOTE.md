NOT SYNTHESIZABLE -- classified, not converted.

Class: static task local
A `static` task local accumulating ACROSS CALLS is one variable observed over simulation time; a netlist elaborates each call site into its own cone and cannot carry the state (see function_static/NOTE.md for the same reasoning).

Upstream evidence:
    task static mytask(int test); int a = 0; a++;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
