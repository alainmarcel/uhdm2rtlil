NOT CONVERTIBLE YET -- Surelog cannot parse the `type()` operator in an expression.

The construct is the type operator used in comparisons and in a `case`.  A
conversion was written (each comparison driving its own output, so which one the
elaborator got wrong would be a value rather than upstream's `$stop`) and Surelog
rejects it before read_uhdm ever sees it:

    dut.sv:11:51: Syntax error: mismatched input ';' expecting '''
    dut.sv:16:18: Syntax error: no viable alternative at input 'type(T))'

Upstream's own form -- `case (type(T))` and `if (type(T) == type(logic[12:0]))`
-- hits the same two errors, so this is a SURELOG front-end gap, not a reader
defect: there is nothing for read_uhdm to get right or wrong.  The `parameter type
T = type(logic[11:0])` default in the module header parses fine; it is `type()`
in an EXPRESSION that does not.

Re-triage when Surelog accepts it: the conversion is straightforward and the
claims are upstream's own four comparisons plus `$bits(T) == 12`.
