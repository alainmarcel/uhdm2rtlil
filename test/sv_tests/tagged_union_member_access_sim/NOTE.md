NOT SYNTHESIZABLE -- classified, not converted.

Class: tagged union
`union tagged` and its `matches` patterns are supported by NONE of the three frontends (measured 2026-10-31: read_verilog syntax error, read_slang `unsupported language feature`, read_uhdm accepts and is silently wrong).  See basic-tagged-union/NOTE.md.

Upstream evidence:
    union tagged ...

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
