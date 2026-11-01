RATCHET -- a TASK-LOCAL declaration with an initialiser, and `++` on it, are
unsupported in a task body.

`task automatic mytask(input int i, output int r); int a = 0; a++; r = a + i;`
must give i + 1.  read_slang gives 13 for i = 12; read_uhdm gives `32'x` with
`Unsupported expression type: int_var` and `Unsupported statement type 39 in task
body`.  The plain `task` (no locals) in the `task` test is correct, so the gap is
the local declaration/increment inside a task.  read_verilog refuses a task call
from always_comb.  Listed in structural_expected_fail.txt and
slang_miter_expected_fail.txt.
