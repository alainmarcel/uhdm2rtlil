// A function with NON-ANSI port declarations (`input [5:0] rem;` inside the
// body) whose locals carry INITIALIZERS -- RSD FP32DivSqrter's SRT table:
//
//     function automatic [2:0] srt_table;
//         input[5:0] rem;
//         input[3:0] div;
//         reg[5:0] th12 = div < 1 ? 6 : div < 2 ? 7 : ... : 11;
//         reg[5:0] th01 =               div < 2 ? 2 : ... :  4;
//              if($signed(rem) < $signed(-th12)) srt_table = -2;
//         ...
//
// Surelog's non-ANSI path (compileTfPortDecl) compiled the declarations
// but dropped their initializer assignments -- and erased them, leaving
// their expression trees with parents into freed memory (a crash in the
// writer's lateBinding once three such functions shared a module).  The
// locals had no driver: read_uhdm resolved `th12` / `th01` to fabricated
// module wires, every quotient digit was wrong and the divider's result
// mantissa was 0 (FP32DivSqrter: 201 co-sim divergences, the miter at
// depth 4 never reaching the end of a divide).  The ANSI form wraps the body
// in a `begin` whose first statements are the initializers; fixed in Surelog
// #4212 (bumped here): the non-ANSI path now prepends them the same way.
module func_nonansi_local_init(
    input  logic [5:0] rem,
    input  logic [3:0] div,
    output logic [2:0] q,
    output logic [5:0] t12,
    output logic [5:0] t01,
    output logic [2:0] q2
);
    function automatic [2:0] srt_table;
        input[5:0] rem;
        input[3:0] div;
        reg[5:0] th12 = div < 1 ? 6 : div < 2 ? 7 : div < 4 ? 8 : div < 5 ? 9 : div < 6 ? 10 : 11;
        reg[5:0] th01 =               div < 2 ? 2 :                             div < 6 ?  3 :  4;
             if($signed(rem) < $signed(-th12)) srt_table = -2;
        else if($signed(rem) < $signed(-th01)) srt_table = -1;
        else if($signed(rem) < $signed( th01)) srt_table =  0;
        else if($signed(rem) < $signed( th12)) srt_table =  1;
        else                                   srt_table =  2;
    endfunction
    // The same thresholds returned directly.
    function automatic [5:0] get12;
        input[3:0] div;
        reg[5:0] th12 = div < 1 ? 6 : div < 2 ? 7 : div < 4 ? 8 : div < 5 ? 9 : div < 6 ? 10 : 11;
        get12 = th12;
    endfunction
    function automatic [5:0] get01;
        input[3:0] div;
        reg[5:0] th01 = div < 2 ? 2 : div < 6 ?  3 :  4;
        get01 = th01;
    endfunction
    // A third non-ANSI function with no local: three in one module was the
    // shape that crashed the writer on the erased initializers.
    function automatic [2:0] cmp;
        input[5:0] rem;
        input[3:0] div;
        if (rem < div) cmp = 1; else cmp = 2;
    endfunction
    assign q   = srt_table(rem, div);
    assign t12 = get12(div);
    assign t01 = get01(div);
    assign q2  = cmp(rem, div);
endmodule
