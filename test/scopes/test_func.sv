module test_func(output reg [15:0] x);
    function [15:0] func_01;
        input [15:0] a, b;
        begin
            func_01 = a + b;
        end
    endfunction
    
    always @* begin
        x = func_01(11, 22);
    end
endmodule