FIXED 2026-11-02 (was a RATCHET) -- a stream into a WIDER target was padded on
the wrong side: the assignment zero-extended the 96-bit stream like any other
value, where LRM 11.4.14.3 left-justifies it.

`{<< 32 {a, b, c}}` into a 128-bit `bit` vector must leave the 96-bit stream in
the HIGH bits with zeros below (LRM 11.4.14.4: padding is on the right of the
stream); upstream's own assertion is `128'h00000003_00000002_00000001_00000000`.
read_slang gives exactly that; read_uhdm used to give
`00000000_00000003_00000002_00000001` -- the stream in the LOW bits.  The
unpadded 96-bit case (`unpack_stream`) was always correct on both, so the gap was
the padding position alone.  read_verilog cannot parse streaming operators.
