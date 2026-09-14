// aes_key_expand with SecMasking=1 + SecSBoxImpl=SBoxImplDom — the
// configuration the masked aes_cipher_core instantiates (the manifest's
// aes_key_expand row is the SecMasking=0 / LUT default).  key_i / key_o
// [NumShares] flattened elem0@LSB.  Wrapper-only top: aes_srcs.py seeds the
// closure from this file's references.
module aes_key_expand_m_flat import aes_pkg::*; (
  input  logic clk_i, input logic rst_ni, input logic cfg_valid_i, input ciph_op_e op_i,
  input  sp2v_e en_i, input logic prd_we_i, output sp2v_e out_req_o, input sp2v_e out_ack_i,
  input  logic clear_i, input logic [3:0] round_i, input key_len_e key_len_i,
  input  logic [2*256-1:0] key_i_flat, output logic [2*256-1:0] key_o_flat,
  input  logic [WidthPRDKey-1:0] prd_i, output logic err_o
);
  logic [7:0][31:0] key_i [2]; logic [7:0][31:0] key_o [2];
  for (genvar s = 0; s < 2; s++) begin : g
    assign key_i[s] = key_i_flat[s*256 +: 256];
    assign key_o_flat[s*256 +: 256] = key_o[s];
  end
  aes_key_expand #(.SecMasking(1'b1), .SecSBoxImpl(SBoxImplDom)) u (
    .clk_i, .rst_ni, .cfg_valid_i, .op_i, .en_i, .prd_we_i, .out_req_o, .out_ack_i, .clear_i,
    .round_i, .key_len_i, .key_i(key_i), .key_o(key_o), .prd_i, .err_o);
endmodule
