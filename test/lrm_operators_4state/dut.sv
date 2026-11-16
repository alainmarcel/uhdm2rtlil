// IEEE 1800-2023 11.4.5 / 11.4.6 / 11.4.11: four-state operator semantics that
// synthesis must fold.  An X or Z bit in a constant operand of == makes the
// result X, of === is compared literally, of ==? is a wildcard; a ?: whose
// condition is X merges the arms bit by bit.  Z in a casez item and X in a
// casex item are don't-cares.  (=== against an X constant is omitted: a
// 2-state simulator turns the X into 0, so it is untestable by co-sim.)
module dut(input logic [3:0] a, input logic c,
           output logic ceq_x, wild, wild_z, output logic [3:0] y_casez, y_casex,
           output logic [3:0] merge);
  assign ceq_x  = (a === 4'b1010) | (a[1:0] !== 2'b01);
  assign wild   = a ==? 4'b1x0x;
  assign wild_z = a !=? 4'bz1z1;
  assign merge  = c ? a : a ^ 4'b1100;
  always_comb begin
    casez (a)
      4'b1???: y_casez = 4'd1;
      4'b01z?: y_casez = 4'd2;
      4'b001?: y_casez = 4'd3;
      default: y_casez = 4'd0;
    endcase
    casex (a)
      4'b1x0x: y_casex = 4'd5;
      4'b0x1x: y_casex = 4'd6;
      default: y_casex = 4'd7;
    endcase
  end
endmodule
