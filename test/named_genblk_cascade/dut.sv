// Reproducer for chipsalliance/synlig#1121
// (sv2v/test/core/named_genblk_cascade.sv).  The DUT body is the
// original test verbatim; `top` instantiates it four times with
// P = 1..3 plus the default (0) so co-sim observes the value of
// `$bits(blkN.<arr>)` for every branch of the cascade.
//
// Expected: o1 == 2, o2 == 3, o3 == 5, o0 == 7.
module mod #(
    parameter P = 0
) (
    output wire [31:0] out
);
    if (P == 1) begin : blk1
        wire w [2];
    end
    else if (P == 2) begin : blk2
        wire x [3];
    end
    else if (P == 3) begin : blk3
        wire y [5];
    end
    else begin : blk4
        wire z [7];
    end
    if (P == 1)
        assign out = $bits(blk1.w);
    else if (P == 2)
        assign out = $bits(blk2.x);
    else if (P == 3)
        assign out = $bits(blk3.y);
    else
        assign out = $bits(blk4.z);
endmodule

module top (
    output wire [31:0] o0,
    output wire [31:0] o1,
    output wire [31:0] o2,
    output wire [31:0] o3
);
    mod #(.P(0)) m0 (.out(o0));
    mod #(.P(1)) m1 (.out(o1));
    mod #(.P(2)) m2 (.out(o2));
    mod #(.P(3)) m3 (.out(o3));
endmodule
