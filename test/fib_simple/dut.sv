module fib_simple(
    input wire [31:0] in,
    output wire [31:0] out
);
    function automatic integer double_it(
        input integer k
    );
        double_it = k * 2;
    endfunction

    assign out = double_it(in);
endmodule