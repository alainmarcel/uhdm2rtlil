NOT SYNTHESIZABLE -- classified, not converted.

Class: dynamic array / queue
`bit [7:0] arr[];` is a DYNAMIC array, unbounded at elaboration time.

Upstream evidence:
    bit [7:0] arr[];

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
