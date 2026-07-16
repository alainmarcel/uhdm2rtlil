// Two always_ff blocks each register a DIFFERENT slice of the same wide reg.
// Each must produce a $dff driving ONLY its slice (disjoint), not the whole
// wire — otherwise the two blocks emit conflicting full-width registers.
// (rp32 tcb_lite_lib_register_request: one block registers the control fields
// of req, another the wdt field.)
module multi_ff_slice (
    input  logic        clk, en,
    input  logic [71:0] d,
    output logic [71:0] q
);
    always_ff @(posedge clk) if (en) q[71:32] <= d[71:32];
    always_ff @(posedge clk) if (en) q[31: 0] <= d[31: 0];
endmodule
