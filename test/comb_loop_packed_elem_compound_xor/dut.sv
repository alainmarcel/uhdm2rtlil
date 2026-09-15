// A COMPOUND assignment on an element of a multi-dim PACKED array inside a
// for loop in always_comb (OpenTitan keymgr_ctrl with KmacEnMasking=1, as the
// Egret top sets it: `key_state_d[i][0] ^= root_key_i.creator_root_key_share0;`
// after a whole-array default).  The read side of `^=` took the raw
// key_state_d wire the block drives: 512 combinational loops in the Egret
// keymgr (the SAT miter still proved it).
module comb_loop_packed_elem_compound_xor #(parameter int CDIs = 2, parameter int Shares = 2,
                                            parameter int Rounds = 2, parameter int W = 4) (
  input  logic [1:0]                                  sel_i,
  input  logic [CDIs-1:0][Shares-1:0][Rounds-1:0][W-1:0] q_i,
  input  logic [Rounds*W-1:0]                         share0_i,
  input  logic [Rounds*W-1:0]                         share1_i,
  input  logic [W-1:0]                                entropy_i,
  input  logic                                        cdi_i,
  output logic [CDIs-1:0][Shares-1:0][Rounds-1:0][W-1:0] d_o
);
  always_comb begin
    d_o = q_i;
    unique case (sel_i)
      2'd0: begin
        for (int i = 0; i < CDIs; i++)
          for (int j = 0; j < Shares; j++)
            d_o[i][j][0] = entropy_i;
      end
      2'd1: begin
        for (int i = 0; i < CDIs; i++) begin
          d_o[i][0] ^= share0_i;
          d_o[i][1] ^= share1_i;
        end
      end
      2'd2: d_o[cdi_i] = ~q_i[cdi_i];
      default: ;
    endcase
  end
endmodule
