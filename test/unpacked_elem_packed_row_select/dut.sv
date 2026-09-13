module unpacked_elem_packed_row_select #(parameter int W = 8) (input logic [2*5*W-1:0] pf, input logic sel, output logic [2*5*W-1:0] of, output logic [5*W/2-1:0] a0_l, output logic [5*W/2-1:0] a1_l);
  localparam int Share = 2;
  typedef logic [4:0][W-1:0] sheet_t;
  sheet_t phase2_in [Share];
  assign phase2_in[0] = pf[5*W-1:0];
  assign phase2_in[1] = pf[2*5*W-1:5*W];
  for (genvar x = 0; x < 1; x++) begin : g_chi_w
    sheet_t sheet0[Share];
    sheet_t sheet1[Share];
    assign sheet0[0] = ~phase2_in[0];
    assign sheet0[1] = phase2_in[1];
    assign sheet1[0] = phase2_in[0];
    assign sheet1[1] = phase2_in[1];
    assign a0_l = {sheet0[0][0][W/2-1:0], sheet0[0][1][W/2-1:0], sheet0[0][2][W/2-1:0], sheet0[0][3][W/2-1:0], sheet0[0][4][W/2-1:0]};
    assign a1_l = {sheet0[1][0][W/2-1:0], sheet0[1][1][W/2-1:0], sheet0[1][2][W/2-1:0], sheet0[1][3][W/2-1:0], sheet0[1][4][W/2-1:0]};
    assign of = sel ? {sheet1[1], sheet1[0]} : {sheet0[1], sheet0[0]};
  end
endmodule
