RATCHET -- a COMPOUND ASSIGNMENT USED AS AN EXPRESSION is mis-evaluated.

`b = (a += 1)` must both update `a` and yield the updated value.  At x = 7
read_verilog gives a = 8 and b = 8; read_uhdm gives a = 1 and b = 1 -- the
expression evaluates to the RHS alone and the `a +` part is lost.  `b = (a -= 1)`
likewise yields 1 instead of 6.

Two forms in the same shape are CORRECT in read_uhdm, which localises the gap:

* the pre-increment form, `b = (++a)` -- see `assign_in_expression`
* a plain chain, `a = (b = (c = x))` -- see `assign_in_expr`

so it is the compound operators specifically.  Probably the same underlying gap
as the `>>>=` signedness loss in `arith_shift_assignment_signed`.

read_verilog is the oracle; read_slang agrees with it.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt, and both entries
must go in the commit that fixes it.
