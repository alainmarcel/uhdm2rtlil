// Test mixed statements function
module function_mixed #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input  logic [WIDTH-1:0] x,
    input  logic [WIDTH-1:0] y,
    input  logic [1:0] mode,
    output logic [WIDTH-1:0] out
);

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

    // Continuous assignment using function
    assign out = func_mixed(x, y, mode);

endmodule