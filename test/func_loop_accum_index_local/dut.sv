// A function whose unrolled loop body BOTH accumulates into a variable and
// advances an int local that the accumulator's own RHS uses as a bit index:
//
//     evicted = (evicted << 1) + (state[pos] ? 0 : 1);   // reads pos
//     pos     = pos + (1 << i);                          // advances pos
//
// The accumulative-loop inliner evaluates the accumulator's RHS a SECOND time
// after the body, to chain the iteration value -- and used to do it against
// the mapping as it stood AFTER the body, so `pos` had already advanced and
// the read indexed state[1] instead of state[0].
//
// Reduced from RSD DCache.sv:100-109 TreeLRU_CalcEvictedWay, called from
// DCacheArray.  With the sweep's 2-way cache that state vector is ONE bit, so
// the out-of-range select folded the whole result to constant X -- a driver
// `check` does not report as undriven -- and DCacheArray's replArrayDataOut
// diverged from cycle 0 on every port bit (290 co-sim divergences against the
// RTL, read_slang clean).
//
// state is 4 bits here so a wrong index is a wrong BIT rather than an X: the
// out-of-range collapse is what the 1-bit geometry adds, not the bug itself.
module func_loop_accum_index_local (
    input  logic [3:0] state,
    output logic [1:0] evicted_way
);
    function automatic [1:0] calc_evicted(input [3:0] st);
        reg [1:0] evicted;
        integer pos;
        integer i;
        begin
            evicted = 0;
            pos = 0;
            for (i = 0; i < 2; i = i + 1) begin
                evicted = (evicted << 1) + (st[pos + evicted] ? 0 : 1);
                pos = pos + (1 << i);
            end
            calc_evicted = evicted;
        end
    endfunction

    always_comb evicted_way = calc_evicted(state);
endmodule
