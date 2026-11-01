NOT SYNTHESIZABLE -- classified, not converted.

Class: string
`$typename` returns a STRING naming a type; nothing a netlist can carry.

Upstream evidence:
    $typename(val) == "logic"

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
