NOT SYNTHESIZABLE -- classified, not converted.

Class: enum method on a runtime value
Measured 2026-10-31:

* `.name()` returns a STRING and is refused by all three frontends
  (read_slang: `expression is not constant`; read_verilog cannot parse the
  method).
* `.next()` / `.prev()` on a RUNTIME value: read_slang refuses outright
  (`unsupported system task 'next'`), read_verilog cannot parse the method, and
  read_uhdm accepts the file and yields `2'x` with
  `hier_path function 'next' - no Function() and no match in current module's
  Task_funcs`.

read_uhdm being silently wrong where the others refuse is worth fixing on its
own.  `.first()`, `.last()` and `.num()` DO work on read_uhdm and read_slang and
are converted (`enum_first`, `enum_last`, `enum_num`), so this class is only the
methods that need a value at run time.  If they gain support, re-triage by
grepping NOTE.md for this class.
