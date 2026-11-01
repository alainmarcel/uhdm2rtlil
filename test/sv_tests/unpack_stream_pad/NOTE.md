RATCHET -- a stream into a WIDER target is padded on the wrong side.

`{<< 32 {a, b, c}}` into a 128-bit `bit` vector must leave the 96-bit stream in
the HIGH bits with zeros below (LRM 11.4.14.4: padding is on the right of the
stream); upstream's own assertion is `128'h00000003_00000002_00000001_00000000`.
read_slang gives exactly that; read_uhdm gives `00000000_00000003_00000002_00000001`
-- the stream in the LOW bits.  The unpadded 96-bit case (`unpack_stream`) is
correct on both, so the gap is the padding position.  read_verilog cannot parse
streaming operators.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
