NOT SYNTHESIZABLE -- classified, not converted.

Class: user-defined nettype
`nettype real real_net [with resolution_fn]` declares a user-defined NET TYPE over a real with a resolution FUNCTION -- a simulation-time driver-resolution mechanism with no netlist form (and `real` nets are not synthesizable in any case).

Upstream evidence:
    nettype real real_net with real_sum;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
