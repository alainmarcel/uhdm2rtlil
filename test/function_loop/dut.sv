// Test loop-based function (bit reversal)
module function_loop #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] x,
    output logic [WIDTH-1:0] out
);

    // Loop-based function (bit reversal)
    function [WIDTH-1:0] func_loop;
        input [WIDTH-1:0] x;
        integer i;
        begin
            func_loop = 0;
            for (i = 0; i < WIDTH; i = i + 1) begin
                func_loop[i] = x[WIDTH-1-i];
            end
        end
    endfunction

    // Continuous assignment using function
    assign out = func_loop(x);

endmodule