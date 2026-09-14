// `arr[k].member` on a PACKED array of packed structs whose member is not at
// offset 0 (OpenTitan keymgr_input_checks: `rom_ctrl_pkg::keymgr_data_t
// [NumRomDigestInputs-1:0] rom_digest_i`, `rom_digest_i[k].data` /
// `.valid`, also as a prim_msb_extend actual and inside $bits()).  Surelog
// elaborates the port as a packed_array_net with no typespec of its own and
// a struct_net element; the element-struct resolver had no case for it, so
// the read fell to the generic walker and produced ONE bit at the member's
// offset (rom_digest_vld_o read 0).
// (msb_extend mirrors prim_msb_extend: replicate the MSB up to OutWidth.)
module msb_extend #(parameter int InWidth = 1, parameter int OutWidth = 1)
  (input logic [InWidth-1:0] in_i, output logic [OutWidth-1:0] out_o);
  assign out_o = {{(OutWidth-InWidth){in_i[InWidth-1]}}, in_i};
endmodule
package psam_pkg;
  typedef struct packed { logic [255:0] data; logic valid; } keymgr_data_t;   // rom_ctrl_pkg order: valid is the LSB
endpackage
module packed_struct_array_member_read #(parameter int N = 1) (
  input psam_pkg::keymgr_data_t [N-1:0] rom_digest_i,
  output logic vld_o, output logic [383:0] pad0_o, output logic v0_o
);
  localparam int MaxWidth = 384;
  function automatic logic valid_chk (logic [MaxWidth-1:0] value);
    return |value & ~&value;
  endfunction
  logic [N-1:0][MaxWidth-1:0] padded;
  for (genvar k = 0; k < N; k++) begin : gen_pad
    msb_extend #(.InWidth($bits(rom_digest_i[k].data)), .OutWidth(MaxWidth)) u_pad (
      .in_i(rom_digest_i[k].data), .out_o(padded[k]));
  end
  always_comb begin
    vld_o = 1'b1;
    for (int k = 0; k < N; k++) begin
      vld_o &= rom_digest_i[k].valid && valid_chk(padded[k]);
    end
  end
  assign pad0_o = padded[0];
  assign v0_o = rom_digest_i[0].valid;
endmodule
