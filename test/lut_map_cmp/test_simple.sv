module test_simple(
    input [3:0] a,
    output o1, o2, o3
);
    // Unsigned comparison works
    assign o1 = 4'b1010 <= a;
    
    // Signed comparison might fail
    assign o2 = 4'sb0101 <= $signed(a);
    
    // Another signed case
    assign o3 = $signed(a) >= 4'sb0000;
endmodule