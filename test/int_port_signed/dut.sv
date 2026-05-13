// Reproduces an `int`-typed output port whose synth output drops the
// `signed` attribute.  Original snippet had a hardcoded `min_v = '1`
// constant — restructured to drive the struct field from an input
// port so the test is controllable and the co-sim can compare both
// unsigned (10-bit) and the `int'(...)` upper-zero-extended view of
// the same value.
//
// The construct under test is the chain
//   logic [9:0] min_v   →   filter_ctl_t struct   →   packed array
//   →   `int'(...)` cast on output of type `int`.

module top(
    input  logic [9:0] min_v_i,
    output int         o
);
    typedef struct packed {
        logic [9:0] min_v;
    } filter_ctl_t;

    filter_ctl_t [1:0][2:0] a;
    assign a[0][0].min_v = min_v_i;
    assign o = int'(a[0][0].min_v);
endmodule
