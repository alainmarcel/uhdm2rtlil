// Regression: SV §11.8.1 operation signedness (signed only if ALL operands
// signed; any unsigned operand => unsigned op), plus the previously-missing
// modulo runtime handler and power context width.  operators-test modes
// 44-63, 80-83.
module top(
    input clk,
    input [3:0] u1, u2,
    input signed [3:0] s1, s2,
    input [4:0] mode,
    output reg [7:0] y
);
always @(posedge clk) begin
    case (mode)
        0:  y <= u1 - s2;   // mixed sub -> unsigned
        1:  y <= s1 - u2;   // mixed sub -> unsigned
        2:  y <= s1 - s2;   // signed sub
        3:  y <= u1 * s2;   // mixed mul -> unsigned
        4:  y <= s1 * u2;   // mixed mul -> unsigned
        5:  y <= s1 * s2;   // signed mul
        6:  y <= u1 / s2;   // mixed div -> unsigned
        7:  y <= s1 / u2;   // mixed div -> unsigned
        8:  y <= u1 % u2;   // modulo (was unhandled -> 0)
        9:  y <= u1 % s2;   // mixed modulo -> unsigned
        10: y <= s1 % s2;   // signed modulo
        11: y <= 4'd2  ** u1;  // power, unsigned base, context width
        12: y <= 4'sd2 ** u1;  // power, signed base
        13: y <= u1 ? s1 : u2; // mixed ternary -> unsigned (zero-extend)
        14: y <= u1 ? s1 : s2; // signed ternary -> sign-extend
        default: y <= '0;
    endcase
end
endmodule
