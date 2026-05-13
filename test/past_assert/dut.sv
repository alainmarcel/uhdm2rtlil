// Minimal repro that pairs a 1-cycle delay flop (`o_w <= i_w`) with a
// `$past` assertion verifying the delay relationship.  Source DUT
// already had observable `o_w`; added an observable `o_past_valid_o`
// for the internal `f_past_valid` flag so co-sim can also compare the
// reset-skip register.
//
// The construct under test:
//   - `$past(i_w)` reads the value of `i_w` from the previous cycle
//   - a concurrent assertion that fires whenever the delayed input
//     should be reflected on the output
//   - `f_past_valid` gates the assertion past the initial reset cycle

`timescale 1ns/1ns
`default_nettype none

module mre (
    i_clk,
    i_w, o_w,
    o_past_valid_o
);
    input  wire i_clk, i_w;
    output reg  o_w;
    output wire o_past_valid_o;

    reg f_past_valid;

    initial f_past_valid = 0;
    always @(posedge i_clk) begin
        o_w <= i_w;
        f_past_valid <= 1;
    end

    assign o_past_valid_o = f_past_valid;

    always @(posedge i_clk)
    if (f_past_valid & $past(i_w))
        assert(o_w);
endmodule
