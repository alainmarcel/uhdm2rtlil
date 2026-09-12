// Minimal repro: a function returning a MULTI-DIMENSIONAL PACKED array (box_t),
// assembled by indexed bit-writes ret[x][y][z]=... in nested loops, then
// `return`ed.  Mirrors keccak_2share bitarray_to_box / box_to_bitarray.
// The module is an identity (s_out === s_in); read_uhdm was folding the function
// result to 0 (whole Keccak datapath zeroed).
module func_3d_packed_return #(
  parameter int Width = 50,
  localparam int W = 2
) (
  input  logic [Width-1:0] s_in,
  output logic [Width-1:0] s_out
);
  typedef logic [4:0][4:0][W-1:0] box_t;   // (x,y,z) 3D packed

  function automatic box_t bitarray_to_box(logic [Width-1:0] s);
    automatic box_t box;
    for (int y = 0; y < 5; y++)
      for (int x = 0; x < 5; x++)
        for (int z = 0; z < W; z++)
          box[x][y][z] = s[W*(5*y+x) + z];
    return box;
  endfunction

  function automatic logic [Width-1:0] box_to_bitarray(box_t st);
    automatic logic [Width-1:0] ba;
    for (int y = 0; y < 5; y++)
      for (int x = 0; x < 5; x++)
        for (int z = 0; z < W; z++)
          ba[W*(5*y+x) + z] = st[x][y][z];
    return ba;
  endfunction

  box_t b;
  assign b = bitarray_to_box(s_in);
  assign s_out = box_to_bitarray(b);
endmodule
