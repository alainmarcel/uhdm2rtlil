// A generate-PARENT local rewritten in place by an always_comb of a NESTED
// generate scope (OpenTitan prim_subst_perm: `data_state_sbox` declared in
// gen_round[r], the block in gen_round[r].gen_enc, with
// `data_state_sbox[k*4 +: 4] = SBOX[data_state_sbox[k*4 +: 4]]`).  Two lookups
// only tried one scope level: the for-loop-written local was dropped from the
// process's temp setup, and the indexed part-select read never threaded the
// in-flight value by the resolved wire name — the rewrite read the wire the
// process drives, a logic loop in every rom_ctrl / sram_ctrl scrambler.
package gpl_pkg;
  parameter logic [15:0][3:0] SBOX4 = {4'h2, 4'h1, 4'h7, 4'h4, 4'h8, 4'hf, 4'he, 4'h3,
                                       4'hd, 4'ha, 4'h9, 4'h0, 4'hb, 4'h6, 4'h5, 4'hc};
endpackage
module genscope_parent_local_inplace_slice #(parameter int W = 16, parameter int R = 2) (
  input  logic [W-1:0] data_i, input logic [W-1:0] key_i,
  output logic [W-1:0] data_o
);
  logic [R:0][W-1:0] data_state;
  assign data_state[0] = data_i;
  for (genvar r = 0; r < R; r++) begin : gen_round
    logic [W-1:0] data_state_sbox, data_state_flipped;
    if (1) begin : gen_enc
      always_comb begin : p_enc
        data_state_sbox = data_state[r] ^ key_i;
        for (int k = 0; k < W/4; k++) begin
          data_state_sbox[k*4 +: 4] = gpl_pkg::SBOX4[data_state_sbox[k*4 +: 4]];
        end
        for (int k = 0; k < W; k++) begin
          data_state_flipped[W - 1 - k] = data_state_sbox[k];
        end
        data_state_sbox = data_state_flipped;
        for (int k = 0; k < W/2; k++) begin
          data_state_sbox[k]       = data_state_flipped[k * 2];
          data_state_sbox[k + W/2] = data_state_flipped[k * 2 + 1];
        end
        data_state[r + 1] = data_state_sbox;
      end
    end
  end
  assign data_o = data_state[R] ^ key_i;
endmodule
