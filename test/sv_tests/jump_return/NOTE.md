FIXED 2026-11-02 (was a RATCHET) -- a BARE `return` inside an `if` arm of a void
function did not skip the rest of the body.  The inliner honoured a return at
the top level of the body but an arm is imported by the ordinary if importer,
which knows nothing of it; `if (c) {A; return;} REST` is now rewritten to
`if (c) {A} else {REST}` before import.

`fun` writes 1, returns early when the argument is 21, and otherwise writes 2.
read_slang gives 1 at a=21 and 2 at a=20; read_uhdm used to give **2 for both**,
so the early return was ignored and every statement after it still ran.

The value form is NOT affected -- `return <expression>` is correct
(`jump_return_expr`), and so is returning the function's own name
(`fun = 7; return fun;` gives 7 on read_uhdm and read_slang alike).  The gap is
the bare `return` as a control transfer.

`read_verilog` cannot read the construct at all
(`ERROR: Can't resolve task name \return`), so read_slang is the oracle and the
slang miter plus this proof are the gates.
