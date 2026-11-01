NOT SYNTHESIZABLE -- classified, not converted.

Class: string
The `string` type is a dynamically-sized object with methods (`len`, `atoi`, `substr`, `toupper`, ...); it has no netlist form.  (A string LITERAL assigned to a packed vector IS synthesizable -- see empty_string and string_bit_array -- which is why those are converted and these are not.)

Upstream evidence:
    string a = "..."; a.len() / a.atoi() / ...

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
