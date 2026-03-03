// Test functions with typedef return types (local and package-scoped)
typedef logic [1:0] T;

package P;
    typedef logic [3:0] S;
endpackage

module top(
    output wire [31:0] out1, out2
);
    // Function returning local typedef T (2-bit)
    function automatic T func1;
        input reg signed inp;
        func1 = inp;
    endfunction
    assign out1 = func1(1'b1);

    // Function returning package-scoped typedef P::S (4-bit)
    function automatic P::S func2;
        input reg signed inp;
        func2 = inp;
    endfunction
    assign out2 = func2(1'b1);
endmodule
