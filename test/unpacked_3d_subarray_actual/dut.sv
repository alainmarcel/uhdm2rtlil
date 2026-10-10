// A SUB-ARRAY of a 3-D unpacked array as an instance port actual
// (RSD DCacheArray: `.we( dataArrayByteWE[i][way] )` on `logic
// dataArrayByteWE[BYTES][WAYS][PORTS]` into `input logic we[PORT_NUM]`).
module child(input logic we[2], input logic [3:0] wv[2], output logic [3:0] o);
  always_comb begin
    o = '0;
    for (int p = 0; p < 2; p++) if (we[p]) o = o | wv[p];
  end
endmodule
module unpacked_3d_subarray_actual(input logic [7:0] we_flat, input logic [31:0] wv_flat, output logic [15:0] o_flat);
  logic we3[2][2][2];
  logic [3:0] wv2[2][2];
  always_comb begin
    for (int i = 0; i < 2; i++)
      for (int w = 0; w < 2; w++) begin
        for (int p = 0; p < 2; p++) we3[i][w][p] = we_flat[(i*2+w)*2+p];
        wv2[i][w] = wv_flat[(i*2+w)*4 +: 4];
      end
  end
  for (genvar i = 0; i < 2; i++) begin : gi
    for (genvar w = 0; w < 2; w++) begin : gw
      child c(.we(we3[i][w]), .wv(wv2[i]), .o(o_flat[(i*2+w)*4 +: 4]));
    end
  end
endmodule
