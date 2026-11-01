NOT SYNTHESIZABLE -- classified, not converted.

Class: disable
`disable block` is a simulation-time control transfer out of a named block; there is no netlist counterpart.

Upstream evidence:
    disable block;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
