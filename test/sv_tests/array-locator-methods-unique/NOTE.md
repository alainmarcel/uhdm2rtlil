NOT SYNTHESIZABLE -- classified, not converted.

Class: dynamic array / queue
Queues, dynamic arrays and associative arrays are unbounded at elaboration time.

Upstream evidence:
    int s[] = { 10, 10, 3, 20, 20, 10 };
    int qi[$];
    

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
