// Bug #3b repro: an unpacked 2D localparam array element used as an INDEX inside
// a function — `state[PiRot[x][y]][x]` (keccak_2share pi step).  PiRot[x][y]
// with constant x,y must const-fold to the array element; read_uhdm did not, so
// the outer index was wrong/X and pi produced garbage.
module func_localparam_2darray_index #(
  parameter int Width = 200,
  localparam int W = 8
) (
  input  logic [Width-1:0] s_in,
  output logic [Width-1:0] s_out
);
  typedef logic [4:0][4:0][W-1:0] box_t;
  localparam int PiRot [5][5] = '{'{0,3,1,4,2},
                                  '{1,4,2,0,3},
                                  '{2,0,3,1,4},
                                  '{3,1,4,2,0},
                                  '{4,2,0,3,1}};
  function automatic box_t pi(box_t state);
    box_t result;
    for (int x = 0; x < 5; x++)
      for (int y = 0; y < 5; y++)
        result[x][y] = state[PiRot[x][y]][x];   // 2D-localparam index lookup
    return result;
  endfunction
  function automatic box_t bitarray_to_box(logic [Width-1:0] s);
    automatic box_t box;
    for (int y=0;y<5;y++) for(int x=0;x<5;x++) for(int z=0;z<W;z++) box[x][y][z]=s[W*(5*y+x)+z];
    return box;
  endfunction
  function automatic logic [Width-1:0] box_to_bitarray(box_t st);
    automatic logic [Width-1:0] ba;
    for (int y=0;y<5;y++) for(int x=0;x<5;x++) for(int z=0;z<W;z++) ba[W*(5*y+x)+z]=st[x][y][z];
    return ba;
  endfunction
  box_t bin,bout; assign bin=bitarray_to_box(s_in); assign bout=pi(bin); assign s_out=box_to_bitarray(bout);
endmodule
