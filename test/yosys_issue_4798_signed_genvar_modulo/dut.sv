// YosysHQ/yosys#4798: Synthesis with -nowidelut gives drastically better results
// https://github.com/YosysHQ/yosys/issues/4798
// sha3's theta step indexes the sheet with `(col - 1) % 5` and `(col + 1) % 5`
// over a genvar.  A genvar is an int, so at col = 0 the first index is -1:
// out of range, i.e. X (LRM 11.4.3 / 7.4.6) -- NOT 4294967295 % 5 = 0, which
// is what an unsigned fold reads (element 0 of the sheet).
module dut(input logic [4:0][7:0] sheet, output logic [7:0] y_prev0, y_next0, y_prev2, y_next2,
           output logic [7:0] m_neg, m_pos);
  genvar col;
  generate
    for (col = 0; col < 1; col++) begin : g0
      assign y_prev0 = sheet[(col - 1) % 5];
      assign y_next0 = sheet[(col + 1) % 5];
    end
    for (col = 2; col < 3; col++) begin : g2
      assign y_prev2 = sheet[(col - 1) % 5];
      assign y_next2 = sheet[(col + 1) % 5];
    end
  endgenerate
  localparam int NEG = (0 - 1) % 5;   // -1
  localparam int POS = (0 - 1) % 5 + 5;   // 4
  assign m_neg = NEG[7:0];
  assign m_pos = POS[7:0];
endmodule
