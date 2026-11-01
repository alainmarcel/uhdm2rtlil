RATCHET -- `$isunknown` is not implemented.

`$isunknown(4'b000x)` must be 1; read_verilog gives 1 and read_uhdm gives **x** --
the unhandled-system-function fallback returning its operand.  Same family as
$countones and the rest.  read_slang refuses `$isunknown` outright
(`unsupported system task`), so read_verilog is the oracle and there is no miter.
