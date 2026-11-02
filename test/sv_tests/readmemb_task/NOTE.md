FIXED 2026-11-02 (was a RATCHET) -- `$readmemb` in an `initial` block on an array
with NO process access was dropped.

read_verilog and read_slang both lower the `$readmemb` into the memory's INIT (one
`$mem_v2` after memory_collect).  read_uhdm's $readmem handler can only fill a
$mem, and the memory-vs-registers classifier scans processes only: an array whose
one other access is the continuous `assign rd = mem[addr]` scored
constant-indexed, became 1024 element wires, and the load fell through to
`Unsupported statement type in sync context`.  An array named by a `$readmem*`
call is now scored dynamic (a $mem).  The .mem payload is vendored in the test
directory because upstream ships none.
