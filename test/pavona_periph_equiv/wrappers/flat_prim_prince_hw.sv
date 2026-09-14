// prim_prince as rom_ctrl_scrambled_rom instantiates it (64/128, 3 half
// rounds, halfway data + key registers).  Wrapper-only top.
module prim_prince_hw_flat (input logic clk_i, input logic rst_ni, input logic valid_i,
  input logic [63:0] data_i, input logic [127:0] key_i, input logic dec_i,
  output logic [63:0] data_o, output logic valid_o);
  prim_prince #(.DataWidth(64), .KeyWidth(128), .NumRoundsHalf(3), .HalfwayDataReg(1'b1), .HalfwayKeyReg(1'b1)) u (
    .clk_i, .rst_ni, .valid_i, .data_i, .key_i, .dec_i, .data_o, .valid_o);
endmodule
