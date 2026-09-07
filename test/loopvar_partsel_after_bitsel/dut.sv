// Regression: a part-select of a LOOP VARIABLE (`i[$clog2(N)-1:0]`) is truncated
// to 1 bit when the SAME loop var was also used earlier in the block as a
// bit-select INDEX (`gnt_o[i] = 1`).  That index use materialises a stray 1-bit
// `\i` wire, and import_part_select sized the loop-var constant base to that
// wire's width — so only bit 0 of `i[1:0]` survived (upper bits X).  A priority
// `for` arbiter (cf. CVA6 tag_cmp) that reports the winner's index hit this.
module loopvar_partsel_after_bitsel #(parameter int NR = 4) (
  input  logic [NR-1:0]         req_i,
  input  logic [NR-1:0][7:0]    addr_i,
  output logic [NR-1:0]         gnt_o,
  output logic [7:0]            addr_o,
  output logic [$clog2(NR)-1:0] id_o
);
  always_comb begin
    gnt_o  = '0;
    addr_o = '0;
    id_o   = '0;
    for (int unsigned i = 0; i < NR; i++) begin
      gnt_o[i] = 1'b1;                 // bit-select index use of the loop var
      addr_o   = addr_i[i];
      id_o     = i[$clog2(NR)-1:0];    // part-select of the SAME loop var
      if (req_i[i]) break;
    end
  end
endmodule
