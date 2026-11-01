NOT SYNTHESIZABLE -- classified, not converted.

Class: bounded queue
A bounded queue is still a queue: its size varies at simulation time.

Upstream evidence:
    
    int q[$:5];
    int r[$];

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
