// An unsized fill literal ('0 / '1) as a COMPARISON operand.
//
// It is context-determined: it must replicate to the width of the other
// operand.  It arrived as a SINGLE BIT, so `x != '1` compared against
// 5'b00001 instead of 5'b11111 — true for almost every value of x.
module dut (
    input  logic [4:0]  x_i,
    input  logic [63:0] w_i,
    output logic        ne_ones_o,
    output logic        eq_ones_o,
    output logic        eq_zero_o,
    output logic        wide_ones_o,
    output logic        lt_ones_o
);
  assign ne_ones_o   = (x_i != '1);
  assign eq_ones_o   = (x_i == '1);
  assign eq_zero_o   = (x_i == '0);     // '0 replicates too
  assign wide_ones_o = (w_i == '1);     // 64-bit operand
  assign lt_ones_o   = (x_i <  '1);     // relational, not just equality
endmodule
