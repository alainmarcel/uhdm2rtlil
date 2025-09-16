module gate(
    off, fib0, fib1
);
    input wire signed [31:0] off;

    function automatic integer fib(
        input integer k
    );
       fib = k;
    endfunction

    function automatic integer fib_wrap(
        input integer k,
        output integer o
    );
        o = off + fib(k);
    endfunction

    output integer fib0;
    output integer fib1;
 

    initial begin : blk
        integer unused;
        unused = fib_wrap(0, fib0);
        unused = fib_wrap(1, fib1);
    end
endmodule
