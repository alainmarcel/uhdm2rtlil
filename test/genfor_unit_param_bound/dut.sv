// A generate-for whose BOUND is a $unit localparam from another file -- the
// shape of every RSD `_flat` harness wrapper:
//
//     for (genvar gi = 0; gi < (FETCH_WIDTH); gi++) begin : g_flat_hitOut
//         assign hitOut_flat[gi*(1) +: (1)] = hitOut[0 + gi];
//     end
//
// Surelog evaluated the bound at elaboration against the module's own
// scopes and the packages, never the other files' compilation-unit
// declarations, so the comparison had no value and the loop elaborated to
// ZERO generate scopes -- silently: no scope, no assigns, the wrapper's
// outputs undriven, ICacheHitLogic's co-sim diverging from cycle 1 while the
// module itself was right.  Fixed in Surelog #4213 (bumped here).  A
// literal bound was always fine (g_lit below).
module genfor_unit_param_bound(
    input  logic a,
    output logic [FETCH_WIDTH-1:0] o_flat,
    output logic [LANES-1:0]       lane,
    output logic [1:0]             o_lit
);
    logic o [FETCH_WIDTH];
    assign o[0] = a;
    assign o[1] = ~a;
    for (genvar gi = 0; gi < (FETCH_WIDTH); gi++) begin : g_flat
        assign o_flat[gi*(1) +: (1)] = o[0 + gi];
    end
    for (genvar k = 0; k < LANES; k++) begin : g_lane
        assign lane[k] = (k % 2 == 0) ? a : ~a;
    end
    for (genvar gi = 0; gi < 2; gi++) begin : g_lit
        assign o_lit[gi] = o[gi];
    end
endmodule
