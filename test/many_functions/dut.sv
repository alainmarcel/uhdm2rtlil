// Test case for multiple function types with various statement combinations
module many_functions #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic [WIDTH-1:0] c,
    input  logic [1:0] sel,
    output logic [WIDTH-1:0] out_arith,
    output logic [WIDTH-1:0] out_bool,
    output logic [WIDTH-1:0] out_case,
    output logic [WIDTH-1:0] out_nested,
    output logic [WIDTH-1:0] out_loop,
    output logic [WIDTH-1:0] out_mixed
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

    // Nested if-else function
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

    // Mixed statements function
    function [WIDTH-1:0] func_mixed;
        input [WIDTH-1:0] x, y;
        input [1:0] mode;
        logic [WIDTH-1:0] result;
        integer i;
        begin
            result = 0;
            
            case (mode)
                2'b00: begin
                    // Arithmetic mode
                    result = x + y;
                end
                2'b01: begin
                    // Bit manipulation mode
                    for (i = 0; i < WIDTH/2; i = i + 1) begin
                        result[2*i] = x[i];
                        result[2*i+1] = y[i];
                    end
                end
                2'b10: begin
                    // Conditional mode
                    if (x[WIDTH-1]) begin
                        result = y >> 1;
                    end else begin
                        result = x << 1;
                    end
                end
                2'b11: begin
                    // Complex mode
                    if (x > y) begin
                        for (i = 0; i < DEPTH; i = i + 1) begin
                            result = result + (x >> i);
                        end
                    end else begin
                        result = y & {{(WIDTH/2){1'b1}}, {(WIDTH/2){1'b0}}};
                    end
                end
            endcase
            
            func_mixed = result;
        end
    endfunction

    // Continuous assignments using functions
    assign out_arith = func_arith(a, b, c);
    assign out_bool = func_bool(a, b, sel);
    assign out_case = func_case(a, sel);
    assign out_nested = func_nested(a, b, c);
    assign out_loop = func_loop(a);
    assign out_mixed = func_mixed(a, b, sel);

endmodule