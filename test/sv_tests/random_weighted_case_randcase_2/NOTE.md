NOT SYNTHESIZABLE -- classified, not converted.

Class: random distribution
`randcase` picks a branch at random with the given weights; it is non-deterministic and has no netlist form.

Upstream evidence:
    randcase ... endcase

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
