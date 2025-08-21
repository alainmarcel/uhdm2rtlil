module mul_sync_reset_test (clk, rst, a, b, p);
    input wire clk, rst;
    input wire [5:0] a;
    input wire [2:0] b;
    output reg [8:0] p;

    always @(posedge clk)
    begin
        if (rst) begin
            p <= 0;
        end
        else begin
            p <= a * b;
        end
    end
endmodule