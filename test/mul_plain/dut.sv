module mul_plain(a, b, p);

    parameter M = 6;
    parameter N = 6;

    input wire [M-1:0] a;
    input wire [N-1:0] b;
    output wire [M+N-1:0] p;

    assign p = a * b;

endmodule