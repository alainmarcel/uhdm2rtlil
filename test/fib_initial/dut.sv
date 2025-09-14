module fib_initial(
    output reg [31:0] out
);
    function automatic integer double_it(
        input integer k
    );
        double_it = k * 2;
    endfunction

    initial begin
        out = double_it(21);
    end
endmodule