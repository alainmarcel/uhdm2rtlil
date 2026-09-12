// Bug #2 repro: a SINGLE-index bit_select on a 2D packed function-local
// (`plane_t c; c[x] = state[x][0]^…`, plane_t = logic [4:0][W-1:0]).
// read_uhdm computed element_width=1 for c[x] (dims live on the TYPESPEC of
// a typedef'd type, not the var's own Ranges), so only the LSB survived and
// the whole keccak theta step collapsed.  Validated read_uhdm == read_slang
// (native read_verilog can't parse the unpacked-array ports, so UHDM-only).
module func_plane_bitsel #(parameter int Width=200, localparam int W=8)
  (input logic [Width-1:0] s_in, output logic [Width-1:0] s_out);
  typedef logic [4:0][4:0][W-1:0] box_t;
  typedef logic [4:0][W-1:0]      plane_t;
  function automatic box_t theta(box_t state);
    plane_t c; box_t result;
    for (int x=0;x<5;x++)
      c[x] = state[x][0]^state[x][1]^state[x][2]^state[x][3]^state[x][4];
    for (int x=0;x<5;x++) for (int y=0;y<5;y++)
      result[x][y] = state[x][y] ^ c[x];
    return result;
  endfunction
  function automatic box_t bitarray_to_box(logic [Width-1:0] s);
    automatic box_t box;
    for (int y=0;y<5;y++) for(int x=0;x<5;x++) for(int z=0;z<W;z++)
      box[x][y][z]=s[W*(5*y+x)+z];
    return box;
  endfunction
  function automatic logic [Width-1:0] box_to_bitarray(box_t st);
    automatic logic [Width-1:0] ba;
    for (int y=0;y<5;y++) for(int x=0;x<5;x++) for(int z=0;z<W;z++)
      ba[W*(5*y+x)+z]=st[x][y][z];
    return ba;
  endfunction
  box_t bin,bout; assign bin=bitarray_to_box(s_in);
  assign bout=theta(bin); assign s_out=box_to_bitarray(bout);
endmodule
