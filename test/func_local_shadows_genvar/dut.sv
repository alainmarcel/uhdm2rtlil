package func_local_shadows_genvar_pkg;
  function automatic logic [31:0] aes_circ_byte_shift(logic [31:0] in, logic [1:0] shift);
    logic [31:0] out;
    logic [31:0] s;
    s = {30'b0,shift};
    out = {in[8*((7-s)%4) +: 8], in[8*((6-s)%4) +: 8],
           in[8*((5-s)%4) +: 8], in[8*((4-s)%4) +: 8]};
    return out;
  endfunction
endpackage
module func_local_shadows_genvar import func_local_shadows_genvar_pkg::*; (input logic [63:0] af, input logic use_rot, output logic [63:0] of, output logic [31:0] sw);
  localparam int NumShares = 2;
  logic [31:0] rot_word_in [NumShares];
  logic [31:0] rot_word_out [NumShares];
  assign rot_word_in[0] = af[31:0];
  assign rot_word_in[1] = af[63:32];
  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_rot_word_out
    assign rot_word_out[s] = aes_circ_byte_shift(rot_word_in[s], 2'h3);
  end
  assign sw = use_rot ? rot_word_out[0] : rot_word_in[0];
  assign of = {rot_word_out[1], rot_word_out[0]};
endmodule
