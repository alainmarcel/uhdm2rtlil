CONVERTED, and gated on read_uhdm's own proof plus read_verilog.

read_slang refuses to bit-convert an UNPACKED union (`value of type 'union' is
unsupported for conversion to bits`), so there is no miter; read_verilog cannot
parse the forward typedef.  The structural proof carries the test.
