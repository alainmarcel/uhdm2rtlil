NOT SYNTHESIZABLE -- classified, not converted.

Class: array reduction method
The array reduction methods (`.sum`, `.and`, `.or`, `.xor`, `.product`) on a FIXED unpacked array are supported by NONE of the three frontends (measured 2026-11-01: read_verilog syntax error; read_slang hits an internal assertion `Assert false && "unsupported ..."`; read_uhdm yields x with `Could not resolve struct member access`).  Upstream's arrays are also DYNAMIC (`byte b[] = {...}`).  read_slang CRASHING on it is worth reporting upstream; read_uhdm being silently wrong is ours to fix before this can be a test.

Upstream evidence:
    y = b.sum;  y = b.and;

There is no synthesizable DUT in which this construct's behaviour is observable,
so the directory keeps `orig.sv` only and stays inert in discovery (no `dut.sv`).
If the construct ever gains a netlist form, re-triage by grepping NOTE.md for
this class name.
