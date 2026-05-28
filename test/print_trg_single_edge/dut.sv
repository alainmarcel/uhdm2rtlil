// Minimal repro for: `$display` inside a single-edge `always @(posedge x)`
// must lower to a `$print` cell with `TRG = x` and `TRG_ENABLE = 1` so
// `synth` keeps the EN-computing logic alive.  Before this PR the cell
// had `TRG_ENABLE = 0` and `EN = 0` (default), and `synth` dead-stripped
// the entire condition cone — leaving zero logic gates.
//
// `cnt` is updated non-blocking in the same always block to give the
// design a real DFF; the `$display`'s condition cone exercises the new
// TRG binding so `synth` keeps the comparator + AND alive.

module top (input clk, input rst, output reg [7:0] cnt);
    always @(posedge clk) begin
        if (rst)
            cnt <= 0;
        else
            cnt <= cnt + 1;
        if (cnt == 8'd42)
            $display("hit at cnt=%d", cnt);
    end
endmodule
