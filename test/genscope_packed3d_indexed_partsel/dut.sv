module genscope_packed3d_indexed_partsel #(parameter int W = 16) (input logic [5*5*W-1:0] s_i, output logic [5*5*W-1:0] s_o);
  typedef logic [4:0][4:0][W-1:0] box_t;
  localparam int RhoOffset [25] = '{0, 36, 3, 105, 210, 1, 300, 10, 45, 66, 190, 6, 171, 15, 253, 28, 55, 153, 21, 120, 91, 276, 231, 136, 78};
  for (genvar i = 0; i < 2; i++) begin : g_rho
    box_t rho_in, rho_out;
    assign rho_in = i == 0 ? s_i : ~s_i;
    for (genvar x = 0; x < 5; x++) begin : gen_rho_x
      for (genvar y = 0; y < 5; y++) begin : gen_rho_y
        localparam int Offset = RhoOffset[5*x+y] % W;
        localparam int ShiftAmt = W - Offset;
        if (Offset == 0) begin : gen_offset0
          assign rho_out[x][y][W-1:0] = rho_in[x][y][W-1:0];
        end else begin : gen_others
          assign rho_out[x][y][W-1:0] = {rho_in[x][y][0+:ShiftAmt], rho_in[x][y][ShiftAmt+:Offset]};
        end
      end
    end
  end
  assign s_o = g_rho[0].rho_out ^ g_rho[1].rho_out;
endmodule
