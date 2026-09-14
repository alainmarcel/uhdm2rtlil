// A PACKAGE 2-D packed parameter table read with an element select AND a
// trailing part-select (OpenTitan prim_prince, every round:
// `prim_cipher_pkg::PRINCE_ROUND_CONST[k][DataWidth-1:0]`).  Surelog emits a
// var_select whose Actual_group is null (the parameter lives in the package),
// so the importer's parameter branch was skipped, the wire paths found
// nothing ("vpiVarSelect: element 'pkg::RC[k]' not found") and the whole XOR
// term was DROPPED — rom_ctrl / sram_ctrl scrambling came out wrong.  The
// var_select handler now slices the folded package table (element k at
// k*elem_w from the LSB) and applies the trailing part/bit select.
package ptv_pkg;
  parameter logic [11:0][63:0] RC = {64'h0123456789abcdef, 64'hfedcba9876543210,
                                     64'h1111111111111111, 64'h2222222222222222,
                                     64'h3333333333333333, 64'h4444444444444444,
                                     64'h5555555555555555, 64'h6666666666666666,
                                     64'h7777777777777777, 64'h8888888888888888,
                                     64'h9999999999999999, 64'haaaaaaaaaaaaaaaa};
endpackage
module pkg_param_table_varselect_partsel #(parameter int DataWidth = 32,
                                           parameter int NumRoundsHalf = 3) (
  input  logic [DataWidth-1:0] d_i,
  output logic [NumRoundsHalf:0][DataWidth-1:0] fwd_o,
  output logic [NumRoundsHalf:0][DataWidth-1:0] bwd_o,
  output logic [DataWidth-1:0] c0_o,
  output logic [7:0] b_o
);
  logic [DataWidth-1:0] c0;
  always_comb begin
    c0  = d_i;
    c0 ^= ptv_pkg::RC[0][DataWidth-1:0];          // compound op, element 0
  end
  assign c0_o = c0;
  assign fwd_o[0] = d_i;
  assign bwd_o[0] = d_i;
  for (genvar k = 1; k < NumRoundsHalf + 1; k++) begin : gen_fwd
    assign fwd_o[k] = fwd_o[k-1] ^ ptv_pkg::RC[k][DataWidth-1:0];
    assign bwd_o[k] = bwd_o[k-1] ^ ptv_pkg::RC[10-NumRoundsHalf+k][DataWidth-1:0];
  end
  // indexed part-select and bit-select trailers on the same table
  assign b_o = {ptv_pkg::RC[11][8 +: 4], ptv_pkg::RC[5][63], ptv_pkg::RC[5][0], ptv_pkg::RC[2][63 -: 2]};
endmodule
