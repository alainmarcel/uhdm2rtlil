module mul_signed_async (clk, rst, en, a, b, p);

    parameter M = 8;
    parameter N = 6;

    input wire signed clk, rst, en;
    input wire signed [M-1:0] a;
    input wire signed [N-1:0] b;
    output reg signed [M+N-1:0] p;

    reg signed [M-1:0] a_reg;
    reg signed [N-1:0] b_reg;

    // signed M*N multiplier with
    // - input and output pipeline registers
    // - asynchronous reset (active high)
    // - clock enable (active high)
    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            a_reg <= 0;
            b_reg <= 0;
            p <= 0;
        end
        else if (en) begin
            a_reg <= a;
            b_reg <= b;
            p <= a_reg * b_reg;
        end
    end

endmodule