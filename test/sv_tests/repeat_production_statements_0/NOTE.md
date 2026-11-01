NOT SYNTHESIZABLE -- classified, not converted.

Class: randsequence
`randsequence` is a simulation-time production generator: it has no netlist form.

Upstream evidence:
        int x;
        randsequence( main )
          main : first;

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
