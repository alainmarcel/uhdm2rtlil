module comb_compound_partsel_rmw(input logic [15:0] kf, input logic sel, output logic [15:0] o, output logic [15:0] o2);
  logic [15:0] key [1];
  logic [15:0] acc;
  always_comb begin
    key[0] = '0;
    for (int i = 0; i < 2; i++) key[0][7:0] ^= kf[i*8 +: 8];
    acc = 16'h1;
    for (int i = 0; i < 2; i++) acc[7:0] ^= kf[i*8 +: 8];
    if (sel) acc[15:8] += 8'd3;
  end
  assign o = key[0];
  assign o2 = acc;
endmodule
