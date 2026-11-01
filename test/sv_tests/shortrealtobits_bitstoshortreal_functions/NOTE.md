RATCHET -- `$shortrealtobits` / `$bitstoshortreal` are not implemented: the
unhandled-system-function fallback returns its operand (see the sysfn ratchets).
read_verilog cannot parse `shortreal` and read_slang refuses the real-to-bits
conversion, so the reference is upstream's own bound check.
