// prim_subst_perm as rom_ctrl / sram_ctrl instantiate it (NumRounds=2; the
// shipped default of 31 rounds is SAT-hard for the miter — co-sim adjudicated
// clean).  Wrapper-only top.
module prim_subst_perm_r2_flat (input logic [63:0] data_i, input logic [63:0] key_i, output logic [63:0] data_o);
  prim_subst_perm #(.DataWidth(64), .NumRounds(2), .Decrypt(0)) u (.data_i, .key_i, .data_o);
endmodule
