module func_table_index_var_select #(parameter int W = 4) (input logic [5*5*W-1:0] s_i, output logic [5*5*W-1:0] s_o);
  typedef logic [4:0][4:0][W-1:0] box_t;
  typedef logic [4:0][W-1:0] plane_t;
  localparam int ThetaIndexX1 [5] = '{4, 0, 1, 2, 3}; // (x-1)%5
  localparam int ThetaIndexX2 [5] = '{1, 2, 3, 4, 0}; // (x+1)%5
  function automatic box_t theta(box_t state);
    plane_t c;
    plane_t d;
    box_t result;
    for (int x = 0 ; x < 5 ; x++) begin
      c[x] = state[x][0] ^ state[x][1] ^ state[x][2] ^ state[x][3] ^ state[x][4];
    end
    for (int x = 0 ; x < 5 ; x++) begin
      for (int z = 0 ; z < W ; z++) begin
        int index_z;
        index_z = (z == 0) ? W-1 : z-1; // (z+1)%W
        d[x][z] = c[ThetaIndexX1[x]][z] ^ c[ThetaIndexX2[x]][index_z];
      end
    end
    for (int x = 0 ; x < 5 ; x++) begin
      for (int y = 0 ; y < 5 ; y++) begin
        result[x][y] = state[x][y] ^ d[x];
      end
    end
    return result;
  endfunction : theta
  assign s_o = theta(s_i);
endmodule
