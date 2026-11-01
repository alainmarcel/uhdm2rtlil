NOT SYNTHESIZABLE -- classified, not converted.

Class: specify block parameter
`specparam` holds timing-check and delay values for a specify block; synthesis has no use for it and read_verilog ignores it, but there is nothing observable to carry.

Upstream evidence:
    specparam delay = 50;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
