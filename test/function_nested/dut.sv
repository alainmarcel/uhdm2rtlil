// Test nested if-else function
module function_nested #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] x,
    input  logic [WIDTH-1:0] y,
    input  logic [WIDTH-1:0] z,
    output logic [WIDTH-1:0] out
);

    // Nested if-else function (find maximum)
    function [WIDTH-1:0] func_nested;
        input [WIDTH-1:0] x, y, z;
        begin
            if (x > y) begin
                if (x > z)
                    func_nested = x;
                else
                    func_nested = z;
            end else begin
                if (y > z)
                    func_nested = y;
                else
                    func_nested = z;
            end
        end
    endfunction

    // Continuous assignment using function
    assign out = func_nested(x, y, z);

endmodule