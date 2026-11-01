RATCHET -- the function is NOT implemented by read_uhdm.

read_uhdm implements only `$clog2`, `$ceil` and `$floor` of the constant system
functions.  For this one it warns `Unhandled system function call` and then
returns the FIRST ARGUMENT unchanged, so the netlist silently carries the operand
where the function's value belongs.  `read_verilog` computes it and is the
oracle, so this test's `test_structural.ys` is listed in
structural_expected_fail.txt and must be removed from it in the commit that
implements the function.  The same single gap covers at least $countones,
$countbits, $onehot, $onehot0, $sqrt, $pow, $ln, $log10, $sin, $cos, $atan,
$atan2, $exp and $hypot.
