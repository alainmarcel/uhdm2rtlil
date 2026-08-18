# arb_idx_cast — KNOWN FAILING (documented in ../failing_tests.txt)

A bit- or part-select of an ELEMENT of a packed array whose element type is a
TYPE PARAMETER collapses to a constant:

    idx_t [3:0] nodes;          // idx_t is `parameter type idx_t = logic [1:0]`
    assign elem_o = nodes[2];        // correct   -> arr_i[5:4]
    assign bit_o  = nodes[2][0];     // WRONG     -> 1'h0   (want arr_i[4])
    assign cat_o  = {1'b1, nodes[2][0:0]};  // WRONG -> 2'h3 (want {1'h1, arr_i[4]})

The whole-element read is right, so the array geometry is known — the wire even
carries correct `packed_elem_width` / `packed_outer_*` attributes.  Only the
second index is dropped.

## Why this matters

`rr_arb_tree` (pulp common_cells) builds its `idx_o` from exactly this shape:

    assign index_nodes[Idx0] = idx_t'({1'b1, index_nodes[Idx1+1][NumLevels-level-2:0]});

so the child index bit is lost and the arbiter reports the wrong port.  That is
what makes `wt_dcache_mem` gate `wr_ack_o` on the wrong port
(`rtl=0 uhdm=1 slang=0` at cycle 4, stable across seeds).

## Why the obvious fix is not enough

Resolving the access from the wire's `packed_*` attributes fixes this test, but
it also claims THREE-dimensional packed selects — tc_sram's
`data_t [NumPorts-1:0][Latency-1:0] rdata_q`, where `rdata_q[i][j]` selects a
whole 32-bit sub-element rather than a bit.  Reading those as 1 bit makes
`rdata_q[i][j] <= rdata_d[i][j]` collapse and the async reset stops being
constant, so `wt_dcache_mem` fails to import at all — a worse bug than the one
being fixed.

Neither discriminator tried works: the wires carry no packed-dimension count,
and the declared range count is the same (1) for both shapes because Surelog
represents `T [N-1:0]` and `data_t [N-1:0][L-1:0]` identically once the element
type is erased.  A correct fix needs the frontend to record how many packed
dimensions a wire has at the point where it still knows.
