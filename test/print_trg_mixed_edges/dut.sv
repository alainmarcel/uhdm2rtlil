// Minimal repro for: multi-trigger `$print` cell emission.  An
// edge-triggered always block with multiple edges in the sensitivity
// list should produce a `$print` whose TRG is a multi-bit SigSpec
// (one bit per trigger signal) with per-bit TRG_POLARITY (1 for
// posedge, 0 for negedge).
//
// After PR2 the `$print` cell is emitted, but TRG_WIDTH = 1 and only
// the first edge trigger gets bound — the rest are dead-stripped.
// Yosys's verilog frontend correctly emits TRG = {trg2, trg1, ...}
// with the matching polarity per bit.

module top (input clk, input a, input b, input cond, output reg [7:0] cnt);
    always @(posedge clk) begin
        if (cond)
            cnt <= cnt + 1;
    end

    // Mixed posedge + negedge with the same pure-effect body.
    always @(posedge a, negedge b)
        if (cond)
            $display("cnt=%d a=%b b=%b", cnt, a, b);
endmodule
