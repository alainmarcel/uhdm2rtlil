// A single-index ROW of a 2-D unpacked array as an instance port actual
// (RSD DCacheArray: `.we( dataArrayWE[way] )` on `logic dataArrayWE[WAYS][PORTS]`
// into `input logic we[PORT_NUM]`).
module child(input logic we[2], input logic [3:0] wv[2], output logic [3:0] o);
  always_comb begin
    o = '0;
    for (int p = 0; p < 2; p++) if (we[p]) o = o | wv[p];
  end
endmodule
module unpacked_2d_row_actual(input logic [3:0] we_flat, input logic [15:0] wv_flat, output logic [7:0] o_flat);
  logic we2[2][2];
  logic [3:0] wv2[2][2];
  always_comb begin
    for (int w = 0; w < 2; w++)
      for (int p = 0; p < 2; p++) begin
        we2[w][p] = we_flat[w*2+p];
        wv2[w][p] = wv_flat[(w*2+p)*4 +: 4];
      end
  end
  for (genvar w = 0; w < 2; w++) begin : gw
    child c(.we(we2[w]), .wv(wv2[w]), .o(o_flat[w*4 +: 4]));
  end
endmodule
