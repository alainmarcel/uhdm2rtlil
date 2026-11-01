RATCHET -- `$readmemh` in an `initial` block is unsupported.

read_verilog and read_slang both lower the `$readmemh` into the memory's INIT (one
`$mem_v2` after memory_collect); read_uhdm warns `Unsupported statement type in
sync context` and produces NO memory at all, so the read port has nothing behind
it.  The .mem payload is vendored in the test directory because upstream ships
none.  Listed in structural_expected_fail.txt and failing_tests.txt.
