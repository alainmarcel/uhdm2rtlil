module unpacked_elem_packed_row_range_write (input logic [2*256-1:0] kf, input logic [31:0] irr0, input logic [31:0] irr1, input logic [1:0] len_i, input logic op_i,
          output logic [2*256-1:0] rf);
  localparam int NumShares = 2;
  logic [7:0][31:0] key_i [NumShares];
  logic [7:0][31:0] regular [NumShares];
  logic [31:0] irregular [NumShares];
  assign key_i[0] = kf[255:0];
  assign key_i[1] = kf[511:256];
  assign irregular[0] = irr0;
  assign irregular[1] = irr1;
  for (genvar s = 0; s < NumShares; s++) begin : gen_shares_regular
    always_comb begin : drive_regular
      unique case (len_i)
        2'd0: begin
          regular[s][7:4] = key_i[s][3:0];
          regular[s][0] = irregular[s] ^ key_i[s][0];
          unique case (op_i)
            1'b0: begin
              for (int i = 1; i < 4; i++) begin
                regular[s][i] = regular[s][i-1] ^ key_i[s][i];
              end
            end
            default: begin
              for (int i = 1; i < 4; i++) begin
                regular[s][i] = key_i[s][i-1] ^ key_i[s][i];
              end
            end
          endcase
        end
        2'd1: begin
          regular[s][7:6] = key_i[s][3:2];
          regular[s][5:2] = key_i[s][3:0];
          for (int i = 0; i < 2; i++) begin
            regular[s][i] = key_i[s][3+i] ^ key_i[s][3+i+1];
          end
        end
        default: regular[s] = {key_i[s][3:0], key_i[s][7:4]};
      endcase
    end
  end
  assign rf = {regular[1], regular[0]};
endmodule
