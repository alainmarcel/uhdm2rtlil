NOT SYNTHESIZABLE -- classified, not converted.

Class: $cast
`$cast` as a function or a task performs a RUN-TIME checked conversion and
reports success, which has no netlist form.  Measured 2026-10-31 with
`ok = $cast(a, 2.1 * 3.7)` inside an `always_comb`: all three frontends refuse or
fail it.  The static cast form IS synthesizable and all three agree on it --
`cast_op` is converted and proves `int'(2.1 * 3.7) == 8`, the same value upstream
expects here -- so what is missing is only the dynamic, success-reporting form.
If `$cast` gains support, re-triage by grepping NOTE.md for this class.
