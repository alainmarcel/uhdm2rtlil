// Reproducer extracted from picorv32.v line 878:
//   { y[31:20], y[10:1], y[11], y[19:12], y[0] } <= $signed({x, 1'b0});
//
// The concat LHS covers all 32 bits of `y` in a swizzled order; the
// RHS is a 21-bit signed value that must sign-extend bits 21..31 of the
// destination from RHS bit 20.  Bit position 20 of `y` (which is at
// LHS concat-position 20) must therefore reflect the sign bit of the
// 21-bit value (= `x[19]`), not 1'b0.
module concat_lhs_signext(
    input wire clk,
    input wire [19:0] x,
    output reg [31:0] y
);
    initial y = 32'h0;
    always @(posedge clk)
        { y[31:20], y[10:1], y[11], y[19:12], y[0] }
            <= $signed({x, 1'b0});
endmodule
