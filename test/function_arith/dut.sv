// Test arithmetic function with multiple operations
module function_arith #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [WIDTH-1:0] c,
    output logic [WIDTH-1:0] out
);

    // Arithmetic function with operations
    function [WIDTH-1:0] func_arith;
        input [WIDTH-1:0] x, y, z;
        logic [WIDTH-1:0] temp;
        begin
            temp = x + y;
            temp = temp - z;
            temp = temp << 1;
            temp = temp | (x & y);
            func_arith = temp ^ z;
        end
    endfunction

    // Continuous assignment using function
    assign out = func_arith(a, b, c);

endmodule