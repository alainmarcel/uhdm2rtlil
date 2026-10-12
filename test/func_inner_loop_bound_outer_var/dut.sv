// An inner for-loop whose BOUND reads the enclosing unrolled loop's variable:
//
//     for (i = 0; i < WAY_BIT_NUM; i = i + 1) begin
//         for (j = 0; j < (1 << i); j = j + 1)
//             next[pos + j] = way[WAY_BIT_NUM - 1 - i];
//         pos = pos + (1 << i);
//     end
//
// The bound was reduced with ExprEval, which knows parameters but NOT the
// value an enclosing unrolled loop currently has, so `(1 << i)` came back
// non-constant, the inner loop was declined ("cannot be unrolled") and its
// body -- the ONLY writer of `next` -- was dropped.  The function then
// returned its `'0` initializer.
//
// Reduced from RSD DCache.sv:112-124 TreeLRU_CalcUpdatedState, called by
// DCacheArray: every tree-LRU update wrote state 0, so the evicted way went
// stale and the row diverged from the RTL from cycle 43 onwards (98 of 301
// co-simulated cycles, read_slang clean).
//
// WAY_BIT_NUM = 2 so the inner bound really varies (1 then 2) and the result
// is a 3-bit tree, not a single bit.
module func_inner_loop_bound_outer_var (
    input  logic [1:0] way,
    output logic [2:0] state
);
    function automatic [2:0] calc_updated_state(input [1:0] w);
        reg [2:0] next;
        integer pos;
        integer i;
        integer j;
        begin
            next = 3'b0;
            pos  = 0;
            for (i = 0; i < 2; i = i + 1) begin
                for (j = 0; j < (1 << i); j = j + 1) begin
                    next[pos + j] = w[1 - i];
                end
                pos = pos + (1 << i);
            end
            calc_updated_state = next;
        end
    endfunction

    always_comb state = calc_updated_state(way);
endmodule
