CONVERTED, with the upstream claim partly out of reach, and UHDM-only.

Upstream's subject is that a `static` function local KEEPS ITS VALUE BETWEEN
CALLS: four calls to `add(5)` assert 5, 10, 15, 20.  That is one variable
observed over simulation TIME; a netlist elaborates each call site into its own
combinational cone and has nowhere to put the carried state, so the accumulation
cannot be expressed in a synthesizable DUT at all.  The conversion proves what a
netlist can show -- that `function static` is accepted and one call returns its
argument -- and records the rest here.

`read_verilog` cannot parse `function static` either
(`syntax error, unexpected TOK_INT`), so read_slang and the structural proof are
this test's gates.
