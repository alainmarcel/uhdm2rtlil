NOT SYNTHESIZABLE -- classified, not converted.

Class: class
An `interface class` is a class construct -- a dynamically-dispatched type with no netlist form.

Upstream evidence:
    interface class base_ic; ... endclass

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
