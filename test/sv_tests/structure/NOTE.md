RATCHET -- with two TYPE KEYS for the same type, the FIRST wins instead of the LAST.

`'{int:0, int:1}` assigns every `int` member: by the LRM (10.9.2) a later key
overrides an earlier one, so both members are 1.  read_slang gives a = 1, b = 1;
read_uhdm gives a = **0**, b = 1 -- it applied the first `int:` key and never
overrode it.  The positional and `default:` forms in the same test are correct.
read_verilog cannot parse an unpacked struct.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt.
