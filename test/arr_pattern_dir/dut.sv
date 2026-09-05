module arr_pattern_dir (
  input  logic [31:0] a_i,
  input  logic        sel_i,
  output logic [63:0] flat_o,
  output logic [63:0] flat2_o
);
  logic [31:0] arr  [2];
  logic [31:0] arr2 [0:1];
  always_comb begin
    if (sel_i) arr = '{a_i, 32'h0};
    else       arr = '{32'hdead_beef, a_i};
  end
  always_comb arr2 = '{a_i, 32'h1};
  assign flat_o  = {arr[1],  arr[0]};
  assign flat2_o = {arr2[1], arr2[0]};
endmodule
