// Minimal repro for: `always @(posedge a, posedge b)` with a pure-effect
// body (no register assignments — only `$display`) currently gets
// routed through the async-reset path in `import_always_ff`, which
// assumes the body is `if (rst) ... else ...` with assignments and
// silently drops bodies that don't match.  Result: no `$print` cell is
// emitted, the trigger signals `a`/`b` are dead-stripped, and the
// design ends up with zero logic gates.
//
// Pattern after PR2: detect a body whose only side effect is
// `$display`/`$check` and route it through a new "edge-triggered
// effect-only" path that calls `import_statement_comb` so the
// `$print` cell gets emitted, then build sync rules for each
// edge trigger.

module top (input clk, input rst, input cond, output reg [7:0] cnt);
    always @(posedge clk) begin
        if (rst)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end

    // Two triggers, pure-effect body (no assignment).
    always @(posedge clk, posedge rst)
        if (cond)
            $display("cnt=%d", cnt);
endmodule
