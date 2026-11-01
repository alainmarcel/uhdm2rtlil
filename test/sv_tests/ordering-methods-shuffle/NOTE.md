NOT SYNTHESIZABLE -- classified, not converted.

Class: dynamic array / queue
The array ordering methods (`sort`, `rsort`, `reverse`, `shuffle`) operate on queues/dynamic arrays; `shuffle` is non-deterministic besides.

Upstream evidence:
    q.sort(); q.rsort(); q.reverse(); q.shuffle();

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
