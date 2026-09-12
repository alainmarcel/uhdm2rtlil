// Bug #3 repro: a var_select with a TRAILING part-select on both sides inside a
// function — `result[x][y][W-1:0] = state[x][y][W-1:0]` (keccak pi/rho shape).
// The trailing [W-1:0] is a `part_select` entry in the var_select's Exprs(), a
// sub-range WITHIN the selected lane, not an index.  read_uhdm dropped it:
//   - WRITE: varselect_const_bitslice treated the part_select as an index (drop)
//   - READ:  the packed var_select fast-path disables on a trailing plain
//            part_select, so state[x][y][W-1:0] read only 1 bit.
// Identity module (s_out === s_in); read_verilog can't parse the ports (UHDM-only).
module func_varsel_trailing_partsel #(
  parameter int Width = 200,
  localparam int W = 8
) (
  input  logic [Width-1:0] s_in,
  output logic [Width-1:0] s_out
);
  typedef logic [4:0][4:0][W-1:0] box_t;

  function automatic box_t lanecopy(box_t state);
    box_t result;
    for (int x = 0; x < 5; x++)
      for (int y = 0; y < 5; y++)
        result[x][y][W-1:0] = state[x][y][W-1:0];   // trailing part-select LHS+RHS
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

  box_t bin,bout; assign bin=bitarray_to_box(s_in); assign bout=lanecopy(bin); assign s_out=box_to_bitarray(bout);
endmodule
