module gate(
    output integer result
);
    // Recursive Fibonacci function
    function automatic integer fib(
        input integer n
    );
        if (n <= 1)
            fib = n;
        else
            fib = fib(n - 1) + fib(n - 2);
    endfunction

    // Wrapper function that calls fib
    function automatic integer fib_wrap(
        input integer k
    );
        fib_wrap = fib(k);
    endfunction

    initial begin
        result = fib_wrap(5);
    end
endmodule