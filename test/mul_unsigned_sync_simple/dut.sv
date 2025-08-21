module mul_unsigned_sync_simple (clk, a, b, p);
    input wire clk;
    input wire [5:0] a;
    input wire [2:0] b;
    output reg [8:0] p;

    always @(posedge clk)
    begin
        p <= a * b;
    end
endmodule