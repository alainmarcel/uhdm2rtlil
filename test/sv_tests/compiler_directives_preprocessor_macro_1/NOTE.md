NOT SYNTHESIZABLE -- classified, not converted.

Class: command-line define
The test expects a macro (`TEST_VAR`, `VAR_1`/`VAR_2`) to arrive from the RUNNER'S COMMAND LINE (`+define+`), not from the source.  Our single-file workflow passes no defines, so the file as written is a syntax error (`TEST_VAR parsed not correctly from template` is emitted as bare text) or an unknown macro.  Defining them in the file would test something else.

Upstream evidence:
    `ifdef TEST_VAR ... TEST_VAR parsed not correctly from template

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
