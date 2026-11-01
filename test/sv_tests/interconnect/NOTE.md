NOT SYNTHESIZABLE -- classified, not converted.

Class: interconnect net
`interconnect bus;` is a type-less generic net resolved against the ports it connects; none of the three frontends implements it (read_verilog and read_slang reject the keyword; read_uhdm fabricates an unsized net).

Upstream evidence:
    interconnect bus;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
