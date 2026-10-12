// A function formal whose name matches an enclosing module's GENVAR.
//
// Surelog elaborates a genvar into a per-generate-instance `parameter` holding
// the iteration value (CLAUDE.md, "A genvar index IS constant"), and the
// bit-select handler looks a parameter up BY NAME.  So reading the formal
// inside the function body found the GENVAR's constant instead of the call's
// argument: the function computed from a constant and its result folded away.
//
// Reduced from RSD DCache.sv: `TreeLRU_CalcUpdatedState(DCacheWayPath way)` is
// read as `way[...]` in its body, and DCacheArray carries
// `for (genvar way = 0; way < DCACHE_WAY_NUM; way++)` for its data, dirty and
// tag arrays.  The D-cache tree-LRU state written was therefore always 0, the
// evicted way went stale, and the row diverged from the RTL from cycle 43
// onwards (98 of 301 co-simulated cycles, read_slang clean).  Found by
// reducing the real module: renaming that genvar cures it.
//
// The genvar loop must stay in the module for the test to mean anything, and
// the function must READ the formal through a select (a whole-formal read
// resolves through a different path).
module func_formal_shadowed_by_genvar (
    input  logic [1:0] a,
    output logic [1:0] y,
    output logic [1:0] g_out
);
    function automatic [1:0] pick(input [1:0] way);
        integer i;
        begin
            pick = 2'b0;
            for (i = 0; i < 2; i = i + 1)
                pick[i] = way[i];
        end
    endfunction

    logic [1:0] gw;
    for (genvar way = 0; way < 2; way++) begin : gblk
        assign gw[way] = a[way];
    end
    assign g_out = gw;

    always_comb y = pick(a);
endmodule
