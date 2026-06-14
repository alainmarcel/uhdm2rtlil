// Regression: gate primitives with MORE than 2 inputs.  A fixed 2-input cell
// silently dropped inputs[2..] (full_adder_gates: carry = a|b not a|b|c).
module top(input a, b, c, d, output o_and, o_or, o_nand, o_nor, o_xor, o_xnor);
    and  U_and  (o_and,  a, b, c, d);
    or   U_or   (o_or,   a, b, c, d);
    nand U_nand (o_nand, a, b, c, d);
    nor  U_nor  (o_nor,  a, b, c, d);
    xor  U_xor  (o_xor,  a, b, c, d);
    xnor U_xnor (o_xnor, a, b, c, d);
endmodule
