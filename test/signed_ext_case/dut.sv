// Regression: signed/width correctness for shifts and unary +/-.
// Each result is assigned to a wider reg, exercising context-determined
// sizing and sign- vs zero-extension (operators-test modes 4-15, 64-71).
module top(
    input clk,
    input [3:0] u1, u2,
    input signed [3:0] s1, s2,
    input [3:0] mode,
    output reg [7:0] y
);
always @(posedge clk) begin
    case (mode)
        0: y <= s1 >>  u2;   // logical >> of signed: $shr A_SIGNED=1 (zero-fill)
        1: y <= s1 >>> u2;   // arithmetic >>> of signed: $sshr (sign-fill)
        2: y <= s1 >>  s2;   // logical >> of signed, signed shift amount
        3: y <= s1 >>> s2;
        4: y <= u1 >>  u2;
        5: y <= s1 <<  u2;
        6: y <= +s1;         // unary plus: preserve value + signedness
        7: y <= -s1;         // unary minus of signed: sign-extend
        8: y <= -u1;         // unary minus of unsigned: zero-extend then negate
        9: y <= +u1;
    endcase
end
endmodule
