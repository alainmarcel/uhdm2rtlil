// `break` inside a for loop of an inlined function, with the loop variable
// read after the loop -- the leading-zeros count of RSD's FP32 multiplier:
//
//     function automatic [9:0] leading_zeros_count;
//         input [22:0] x;
//         for (leading_zeros_count = 0; leading_zeros_count <= 22;
//              leading_zeros_count = leading_zeros_count + 1)
//             if (x >> (22-leading_zeros_count) != 0) break;
//     endfunction
//
// The inliner unrolled the loop with the loop variable as a per-iteration
// constant and had no handler for `break`: every iteration's `if` arm was
// empty, the return variable kept its `= 0` init, and `-leading_zeros_count(m)`
// was 0 for every subnormal input (FMulStage0's one co-sim divergence in 300
// cycles; the rest of the FP cluster inlines the same function).  With an
// `int` counter and `f = i` after the loop (fc below) the result was not even
// wrong but UNDRIVEN: `i` read the block-local wire nothing drives.
//
// Now a per-loop break flag (an SSA value like the return guard) kills the
// rest of the iteration and every later one, and the loop variable's
// post-loop value is the index of the first iteration that broke, else the
// natural exit value.
module func_loop_break_return_var(
    input  logic [22:0] x,
    output logic [9:0]  neg_lzc,   // -fa(x): the RSD call site
    output logic [9:0]  lzc,       // fa(x)
    output logic [9:0]  lzc_int,   // separate counter, read after the loop
    output logic [4:0]  lzc_ret    // FP32PipelinedAdder: `i++`, `return i`
);
    function automatic [9:0] fa;
        input [22:0] x;
        for (fa = 0; fa <= 22; fa = fa + 1)
            if (x >> (22-fa) != 0) break;
    endfunction

    function automatic [9:0] fc;
        input [22:0] x;
        int i;
        for (i = 0; i <= 22; i = i + 1)
            if (x >> (22-i) != 0) break;
        fc = i;
    endfunction

    function automatic logic [4:0] fr(input logic [24:0] x);
        logic [4:0] i;
        for (i = 0; i <= 24; i++) begin
            if (x[24-i]) break;
        end
        return i;
    endfunction

    assign neg_lzc = -fa(x);
    assign lzc     = fa(x);
    assign lzc_int = fc(x);
    assign lzc_ret = fr({x, 2'b00});
endmodule
