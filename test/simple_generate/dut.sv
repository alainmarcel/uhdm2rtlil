module simple_generate(clk, a, b, y);

input clk;
input [3:0] a, b;
output reg [3:0] y;

genvar i;
generate
    for (i = 0; i < 4; i = i + 1) begin:gen_loop
        wire tmp;
        assign tmp = a[i] & b[i];
        always @(posedge clk)
            y[i] <= tmp;
    end
endgenerate

endmodule