RATCHET -- the EXPONENT of a real literal with UNDERSCORES is dropped.

`236.123_763_e-12` is 2.36e-10 and rounds to 0 when assigned to an integral
target; read_verilog and read_slang give 0 and read_uhdm gives **236** -- the
mantissa with the exponent ignored.  The other eight spellings, including
`1.30e-2`, `29E-2` and `1.2E12`, are correct on all three, so the gap is specific
to a literal that combines underscores with an exponent.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt.
