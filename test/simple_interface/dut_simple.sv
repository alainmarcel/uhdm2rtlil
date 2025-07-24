// Simplified version without interfaces for now
// This demonstrates the concept but uses traditional module ports
module submodule_simple #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,  
    input  logic [WIDTH-1:0] c,
    output logic [WIDTH-1:0] out
);
    // Bitwise AND of three signals
    assign out = a & b & c;
endmodule

module simple_interface (
    input  logic [7:0]  a1, b1, c1,
    input  logic [7:0]  a2, b2, c2,
    input  logic [15:0] a3, b3, c3,
    output logic [7:0]  out1,
    output logic [7:0]  out2,
    output logic [15:0] out3
);

    // First instance with WIDTH=8
    submodule_simple #(.WIDTH(8)) inst1 (
        .a(a1),
        .b(b1),
        .c(c1),
        .out(out1)
    );

    // Second instance with WIDTH=8
    submodule_simple #(.WIDTH(8)) inst2 (
        .a(a2),
        .b(b2),
        .c(c2),
        .out(out2)
    );

    // Third instance with WIDTH=16
    submodule_simple #(.WIDTH(16)) inst3 (
        .a(a3),
        .b(b3),
        .c(c3),
        .out(out3)
    );

endmodule