# unpacked_elem_write_flat — root cause of latch_perf_counters' miter failure

A per-element write in a for loop lands on the WRONG BITS when the same
unpacked array is also read as a WHOLE array elsewhere in the module.

    logic [63:0] q[4:1], d[4:1];
    always_comb for (int unsigned k = 1; k <= 4; k++) q[k] = base_i + 64'(k);
    always_comb begin
      d = q;                 // <-- whole-array read materialises the flat wire
      d[addr_i] = wdata_i;
    end

RTLIL for the loop write, with the whole-array read present:

    assign \q [1] <expr>[0]      // bit 1 of the FLAT 256-bit wire  (WRONG)

and without it (same loop, same 1-based array):

    assign \q[1] <expr>          // the 64-bit ELEMENT wire         (correct)

So the element write degrades to a single-bit write on the flat wire. Every
element ends up holding the same value, and `d[1]^d[2]^d[3]^d[4]` collapses:
uhdm returns 0 for every address where slang returns `4^addr`.

The dynamic-index write itself is fine — `emit_dynamic_unpacked_array_write`
honours the declared low bound, emits one read-modify-write mux per element at
`(k - array_low) * elem_w`, and compares `addr_i` against the declared indices
(`3'001`, `3'010`, …). Removing the whole-array read makes the miter pass, and
removing the dynamic write also makes it pass; both are needed to expose it.

This is what makes `latch_perf_counters` fail its slang miter — a test that had
been failing silently since it was added (3e77690b) because nothing ran the
miters until PR #611.

## Where to fix

The LHS of `q[k]` with a constant index must resolve to the element wire
`\q[k]`, not to bit k of the flat `\q`, whenever the expanded element wires
exist. The two representations coexist (`connect \d[1] \d [63:0]` …), and the
write path picks the flat one once a whole-array read has forced it into being.
