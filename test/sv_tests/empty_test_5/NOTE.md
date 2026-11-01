NOT SYNTHESIZABLE -- classified, not converted.

Class: empty input
The file is empty (or holds only comments).  The construct under test IS the absence of content, so adding a module to make it observable would destroy it.

Upstream evidence:
    <no declarations at all>

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
