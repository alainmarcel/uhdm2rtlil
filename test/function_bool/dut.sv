// Test boolean logic function with if-else chain
module function_bool #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [1:0] sel,
    output logic [WIDTH-1:0] out
);

    // Boolean logic function
    function [WIDTH-1:0] func_bool;
        input [WIDTH-1:0] x, y;
        input [1:0] mode;
        begin
            if (mode == 2'b00)
                func_bool = x & y;
            else if (mode == 2'b01)
                func_bool = x | y;
            else if (mode == 2'b10)
                func_bool = x ^ y;
            else
                func_bool = ~(x & y);
        end
    endfunction

    // Continuous assignment using function
    assign out = func_bool(a, b, sel);

endmodule