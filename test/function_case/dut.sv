// Test case statement function
module function_case #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] x,
    input  logic [1:0] sel,
    output logic [WIDTH-1:0] out
);

    // Case statement function
    function [WIDTH-1:0] func_case;
        input [WIDTH-1:0] x;
        input [1:0] sel;
        begin
            case (sel)
                2'b00: func_case = x;
                2'b01: func_case = x << 1;
                2'b10: func_case = x << 2;
                2'b11: func_case = x << 3;
                default: func_case = 0;
            endcase
        end
    endfunction

    // Continuous assignment using function
    assign out = func_case(x, sel);

endmodule