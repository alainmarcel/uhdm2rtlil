NOT SYNTHESIZABLE -- classified, not converted.

Class: delay control
The behaviour under test is a DELAY, which synthesis discards.

Upstream evidence:
          // For now increment time and order locally only, do some simple checks
          #5;
          i++;

There is no synthesizable DUT in which this construct's behaviour is
observable, so the directory keeps `orig.sv` only and stays inert in discovery
(no `dut.sv`).  If the construct ever gains a netlist form, re-triage by
grepping NOTE.md for this class name.
