RATCHET -- a BARE `return` in a VOID FUNCTION does not skip the rest of the body.

`fun` writes 1, returns early when the argument is 21, and otherwise writes 2.
read_slang gives 1 at a=21 and 2 at a=20; read_uhdm gives **2 for both**, so the
early return is ignored and every statement after it still runs.

The value form is NOT affected -- `return <expression>` is correct
(`jump_return_expr`), and so is returning the function's own name
(`fun = 7; return fun;` gives 7 on read_uhdm and read_slang alike).  The gap is
the bare `return` as a control transfer.

`read_verilog` cannot read the construct at all
(`ERROR: Can't resolve task name \return`), so read_slang is the oracle and the
slang miter plus this proof are the gates.  Listed in
structural_expected_fail.txt and slang_miter_expected_fail.txt; both entries must
go in the commit that fixes it.
