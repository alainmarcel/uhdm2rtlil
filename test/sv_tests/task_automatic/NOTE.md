FIXED 2026-11-02 (was a RATCHET) -- a TASK-LOCAL declaration with an
initialiser, and `++` on it, were unsupported in a task body: the initialiser
arrives as an assignment whose LHS is the int_var node itself (not a ref_obj),
and an increment statement had no case in the inliner; both are now mapped onto
the local's temp (the increment as the assignment `a = a + 1`).

`task automatic mytask(input int i, output int r); int a = 0; a++; r = a + i;`
must give i + 1.  read_slang gives 13 for i = 12; read_uhdm used to give `32'x` with
`Unsupported expression type: int_var` and `Unsupported statement type 39 in task
body`.  The plain `task` (no locals) in the `task` test is correct, so the gap is
the local declaration/increment inside a task.  read_verilog refuses a task call
from always_comb.
