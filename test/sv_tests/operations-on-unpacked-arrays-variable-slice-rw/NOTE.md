RATCHET -- an INDEXED PART-SELECT of an UNPACKED array loses the array.

`arr_b[4+:c] = arr_a[1+:c]` on `bit arr_a [7:0]` must copy c elements from offset
1 to offset 4.  read_slang does it (8'b01110000 for all-ones into all-zeros);
read_uhdm warns `Base signal 'arr_a' not found in module or generate scope` for
BOTH arrays and the destination reads all-zeros.

`read_verilog` rejects the form outright (`Invalid array access`), so read_slang
is the only oracle.  The PACKED counterpart is correct -- see
`operations-on-packed-arrays-variable-slice-rw`, which passes -- so the gap is
the unpacked case.

Listed in structural_expected_fail.txt and slang_miter_expected_fail.txt.
