NOT SYNTHESIZABLE -- classified, not converted.

Class: procedural assign / deassign
`assign`/`deassign` inside an always block override a variable's drivers for part of a simulation; a netlist's drivers are fixed at elaboration.

Upstream evidence:
    assign q = 0; ... deassign q;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
