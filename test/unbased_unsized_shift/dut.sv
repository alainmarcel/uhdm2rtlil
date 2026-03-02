// Test unbased unsized fill literals ('0, '1) in shift operations.
// Per SV LRM, '0/'1 self-replicate to the context width (LHS width), so
// '1 << 8 in a 64-bit context must produce 64'hFFFF_FFFF_FFFF_FF00, not 64'h0.
module unbased_unsized_shift (
    input  [63:0] d,
    output [63:0] s0c, s1c,
    output [63:0] s0d, s1d
);
    assign s0c = '0 << 8;
    assign s1c = '1 << 8;
    assign s0d = '0 << d;
    assign s1d = '1 << d;
endmodule
