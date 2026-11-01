RATCHET -- a RANGED enum member list does not create its members.

`enum {start=10, stop[11:13]}` must generate stop11, stop12 and stop13.
read_slang resolves them to 11, 12 and 13; read_uhdm reports
`Reference to unknown signal: stop11` and fabricates a 1-bit wire, so every
generated name reads as an undriven bit.

`read_verilog` cannot parse a ranged enum at all, so read_slang is the oracle.
Same defect as `enum_sequence` (the `step[10]` count form); both are listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt, and both entries
must go in the commit that fixes it.
