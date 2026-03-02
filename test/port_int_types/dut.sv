// Test that built-in integer port types (byte, shortint, etc.) sign-extend
// correctly when assigned to wider wires.
// byte          = signed [7:0]   → assign to [31:0] must sign-extend
// byte unsigned = unsigned [7:0] → assign to [31:0] must zero-extend
// shortint          = signed [15:0]
// shortint unsigned = unsigned [15:0]
module port_int_types (
    output byte             a,
    output byte unsigned    b,
    output shortint         c,
    output shortint unsigned d,
    output [31:0]           a_ext,
    output [31:0]           b_ext,
    output [31:0]           c_ext,
    output [31:0]           d_ext
);
    assign a = -1;
    assign b = -2;
    assign c = -3;
    assign d = -4;
    assign a_ext = a;
    assign b_ext = b;
    assign c_ext = c;
    assign d_ext = d;
endmodule
