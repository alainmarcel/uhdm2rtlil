module keyport_child #(parameter int NumShares = 2) (input logic [7:0][31:0] key_i [NumShares], input logic [2:0] sel,
                       output logic [7:0][31:0] key_o [NumShares], output logic [31:0] w3);
  for (genvar s = 0; s < NumShares; s++) begin : g
    assign key_o[s][3:0] = key_i[s][7:4];
    assign key_o[s][7:4] = {key_i[s][3] ^ key_i[s][2], key_i[s][1], key_i[s][0] + 32'd1, key_i[s][5]};
  end
  assign w3 = key_i[1][sel] ^ key_i[0][3];
endmodule
module unpacked_port_packed2d_word_select (input logic [2*256-1:0] kf, input logic [2:0] sel, output logic [2*256-1:0] of, output logic [31:0] w3);
  logic [7:0][31:0] k [2]; logic [7:0][31:0] o [2];
  assign k[0] = kf[255:0]; assign k[1] = kf[511:256];
  keyport_child u (.key_i(k), .sel(sel), .key_o(o), .w3(w3));
  assign of = {o[1], o[0]};
endmodule
