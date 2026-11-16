// IEEE 1800-2023 11.6 / 11.8: expression bit lengths and signedness.  The
// context width propagates into context-determined operands (the carry of
// a + b survives in a 9-bit target), self-determined operands keep their own
// width ({}, reduction, shift amount, ** exponent, comparison operands), and
// a single unsigned operand makes the whole expression unsigned.
module dut(input  logic [7:0] a, b, input logic signed [3:0] s, input logic [3:0] u,
           output logic [8:0] carry, output logic [15:0] prod,
           output logic [8:0] cat_nocarry, output logic [7:0] shifted,
           output logic [9:0] mixed, output logic [9:0] sext,
           output logic cmp_wide, output logic [7:0] tern_w,
           output logic [3:0] sel_w, output logic [15:0] avg);
  assign carry       = a + b;                   // 9-bit context keeps carry
  assign prod        = a * b;                   // 16-bit context
  assign cat_nocarry = {1'b0, a + b};           // {} is self-determined: 8 bits
  assign shifted     = (a + b) >> 1;            // 8-bit context: carry lost
  assign mixed       = s + u;                   // unsigned: s zero-extended
  assign sext        = s + 4'sd0;               // all signed: s sign-extended
  assign cmp_wide    = (a + b) > 9'd255;        // operands sized to 9 bits
  assign tern_w      = s[3] ? a : {4'b0, u};
  assign sel_w       = a[b[2:0] +: 4];
  assign avg         = (16'(a) + 16'(b)) >> 1;
endmodule
