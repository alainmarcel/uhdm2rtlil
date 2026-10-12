// A function whose unrolled loop body writes a bit of a local at an index that
// reads a THREADED ACCUMULATOR, and only then accumulates it:
//
//     we[pos + c] = weIn;                 // index reads pos and c
//     c   = (c << 1) + way[WB - 1 - i];   // c is the loop accumulator
//     pos = pos + (1 << i);
//
// The dynamic bit/element write on a function local was skipped outright
// inside an unrolled loop, on the assumption that indices are constant there.
// They are not when the index reads an accumulator: the accumulator machinery
// keeps it on an SSA wire, so the index is non-constant, the write was
// silently DROPPED, and the function returned its `'0` initializer.
//
// Reduced from RSD DCache.sv:127-139 TreeLRU_CalcWriteEnable, called by
// DCacheArray.  With it dead the D-cache LRU write enable was stuck at 0, the
// LRU array never updated, and the row diverged from the RTL from the first
// update onwards (98 of 301 co-simulated cycles, read_slang clean).
//
// WB = 2 on purpose: with a single iteration the index happens to be constant
// at the write (both locals still hold their initializers), so the dynamic
// case only appears from the second iteration on.
module func_loop_dyn_bit_write_accum_index (
    input  logic       weIn,
    input  logic [1:0] way,
    output logic [2:0] we_o
);
    function automatic [2:0] calc_write_enable(input we_in, input [1:0] w);
        reg [2:0] we;
        integer pos;
        integer c;
        integer i;
        begin
            pos = 0;
            c   = 0;
            we  = 3'b0;
            for (i = 0; i < 2; i = i + 1) begin
                we[pos + c] = we_in;
                c   = (c << 1) + w[1 - i];
                pos = pos + (1 << i);
            end
            calc_write_enable = we;
        end
    endfunction

    always_comb we_o = calc_write_enable(weIn, way);
endmodule
