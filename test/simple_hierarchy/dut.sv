module submodule #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire [WIDTH-1:0] c,
    output wire [WIDTH-1:0] out
);

    // Bitwise AND of three signals
    assign out = a & b & c;

endmodule

module top (
    input  wire [7:0]  a1, b1, c1,
    input  wire [7:0]  a2, b2, c2,
    input  wire [15:0] a3, b3, c3,
    output wire [7:0]  out1,
    output wire [7:0]  out2,
    output wire [15:0] out3
);

    // First instance with WIDTH=8
    submodule #(.WIDTH(8)) inst1 (
        .a(a1),
        .b(b1),
        .c(c1),
        .out(out1)
    );

    // Second instance with WIDTH=8 (same as first)
    submodule #(.WIDTH(8)) inst2 (
        .a(a2),
        .b(b2),
        .c(c2),
        .out(out2)
    );

    // Third instance with WIDTH=16 (different parameter)
    submodule #(.WIDTH(16)) inst3 (
        .a(a3),
        .b(b3),
        .c(c3),
        .out(out3)
    );

endmodule