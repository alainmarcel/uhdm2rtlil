module mul_sync_enable_test (clk, rst, en, a, b, p);
    input wire clk, rst, en;
    input wire [5:0] a;
    input wire [2:0] b;
    output reg [8:0] p;

    always @(posedge clk)
    begin
        if (rst) begin
            p <= 0;
        end
        else if (en) begin
            p <= a * b;
        end
    end
endmodule