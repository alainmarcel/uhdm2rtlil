RATCHET -- `$realtobits` / `$bitstoreal` are not implemented.

`int'($bitstoreal($realtobits(12.45)) * 100)` must be 1245.  read_slang gives
1245; read_uhdm gives **1200**, with `Unhandled system function call` warnings --
the unhandled-system-function fallback that returns its first argument (so the
value is 12.45 passed through and then truncated at the int boundary).  Same
family as $countones, $sqrt, $pow and the rest; see the sysfn ratchets.
read_verilog cannot parse these, so read_slang is the oracle.
