// A `parameter type`-free reduction of PULP axi_id_serialize's ID remap table.
//
// `IdMap` is a 2-D UNPACKED parameter array whose default is a `'{default: v}`
// pattern.  Surelog expanded that default over the OUTERMOST dimension only, so
// each row held the bare element value and `IdMap[i][j]` selected nothing; the
// const function reading it then failed to fold and `IdTable` came out all
// zero, which made `sel_o` the constant 0 instead of a real lookup.
//
// `remap_default` takes the parameter's default, `remap_explicit` overrides it,
// so the table is pinned in both directions.
module remap #(
  parameter int unsigned IdWidth    = 4,
  parameter int unsigned NumUniq    = 4,
  parameter int unsigned BaseOffset = 4,
  parameter int unsigned MapEntries = 2,
  // index [0] of each entry is the input id to match, index [1] the output id
  parameter int unsigned IdMap [MapEntries-1:0][0:1] = '{default: {32'b0, 32'b0}}
) (
  input  logic [IdWidth-1:0] id_i,
  output logic [3:0]         sel_o
);
  typedef logic [3:0]              ent_t;
  typedef ent_t [2**IdWidth-1:0]   map_t;

  function automatic map_t build_map();
    map_t ret = '0;
    for (int unsigned i = 0; i < 2**IdWidth; ++i)
      ret[i] = (i + BaseOffset) % NumUniq;
    for (int unsigned i = 0; i < MapEntries; ++i)
      ret[IdMap[i][0]] = IdMap[i][1];
    return ret;
  endfunction

  localparam map_t IdTable = build_map();

  assign sel_o = IdTable[id_i];
endmodule

module param_2d_unpacked_default_map (
  input  logic [3:0] id_i,
  output logic [3:0] def_o,
  output logic [3:0] exp_o
);
  remap #(
    .IdWidth(4), .NumUniq(4), .BaseOffset(4), .MapEntries(2)
  ) i_default (.id_i(id_i), .sel_o(def_o));

  remap #(
    .IdWidth(4), .NumUniq(4), .BaseOffset(4), .MapEntries(2),
    .IdMap('{'{5, 1}, '{9, 2}})
  ) i_explicit (.id_i(id_i), .sel_o(exp_o));
endmodule
