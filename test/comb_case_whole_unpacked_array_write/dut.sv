module comb_case_whole_unpacked_array_write #(parameter int W = 4, parameter bit EN = 1) (input logic [3:0] sel, input logic low, input logic [2*25*W-1:0] a_flat, input logic [2*25*W-1:0] b_flat,
  output logic [2*25*W-1:0] s_o_flat);
  localparam int Share = 2;
  typedef logic [4:0][4:0][W-1:0] box_t;
  box_t state_in [Share]; box_t p1 [Share]; box_t p2 [Share]; box_t state_out [Share]; box_t iota [Share];
  function automatic box_t f(logic [25*W-1:0] v); box_t r; for (int x=0;x<5;x++) for (int y=0;y<5;y++) r[x][y] = v[W*(5*y+x) +: W] ^ W'(x+y); return r; endfunction
  function automatic logic [25*W-1:0] g(box_t s); logic [25*W-1:0] r; for (int x=0;x<5;x++) for (int y=0;y<5;y++) r[W*(5*y+x) +: W] = ~s[x][y]; return r; endfunction
  for (genvar i = 0; i < Share; i++) begin : g_io
    assign state_in[i] = f(a_flat[i*25*W +: 25*W]);
    assign iota[i] = f(b_flat[i*25*W +: 25*W]);
    assign s_o_flat[i*25*W +: 25*W] = g(state_out[i]);
  end
  if (EN) begin : g_2share
    always_comb begin
      unique case (sel)
        4'd9: state_out = p1;
        4'd6: state_out = p2;
        default: state_out = p1;
      endcase
    end
  end else begin : g_single
    assign state_out = p2;
  end
  assign p1 = iota;
  if (EN) begin : g_p2
    for (genvar x = 0; x < 5; x++) begin : gx
      for (genvar y = 0; y < 5; y++) begin : gy
        assign p2[0][x][y] = low ? {state_in[0][x][y][W-1:W/2], iota[0][x][y][W/2-1:0]} : {iota[0][x][y][W-1:W/2], state_in[0][x][y][W/2-1:0]};
        assign p2[1][x][y] = low ? {state_in[1][x][y][W-1:W/2], iota[1][x][y][W/2-1:0]} : {iota[1][x][y][W-1:W/2], state_in[1][x][y][W/2-1:0]};
      end
    end
  end
endmodule
