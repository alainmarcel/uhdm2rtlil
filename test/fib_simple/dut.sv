module gate(
    off, fib2
);
    input wire signed [31:0] off;

    function automatic integer fib(
        input integer k
    );
        if (k == 0)
            fib = 0;
        else if (k == 1)
            fib = 1;
        else
            fib = fib(k - 1) + fib(k - 2);
    endfunction

    function automatic integer fib_wrap(
        input integer k,
        output integer o
    );
        o = off + fib(k);
    endfunction

    output integer fib2;
   
    initial begin : blk
        integer unused;
        unused = fib_wrap(2, fib2);
    end
endmodule