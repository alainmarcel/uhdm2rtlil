// A function whose packed multi-dimensional formal is bound to a CONSTANT
// parameter table (OpenTitan keymgr's `perm_data(data, RndCnstRandPerm)`,
// `rand_perm_t perm_sel` = logic [31:0][4:0]): `perm_sel[k]` is the k-th
// 5-bit entry.  The constant-argument fast path of the bit-select importer
// returned a single BIT of the table, so every permutation index folded to
// 0/1 and keymgr_kmac_if's decoy data / sideload keys came out wrong.
package fct_pkg;
  parameter int LfsrWidth = 64;
  parameter int RandWidth = LfsrWidth / 2;
  typedef logic [RandWidth-1:0][$clog2(RandWidth)-1:0] rand_perm_t;
  parameter rand_perm_t RndCnstRandPermDefault = {
    160'h62089181d2a6be2ce145e2e27099ededbd7dceb0
  };
  function automatic logic[RandWidth-1:0] perm_data (logic [RandWidth-1:0] data,
    rand_perm_t perm_sel);

    for (int k = 0; k < 32; k++) begin : gen_data_loop
      perm_data[k] = data[perm_sel[k]];
    end

  endfunction
endpackage
module func_const_table_packed_elem_select import fct_pkg::*; (input logic [1:0][RandWidth-1:0] entropy_i, output logic [RandWidth-1:0] dec_o, output logic [63:0] decoy_o);
  localparam int DecoyCopies = 64 / RandWidth;
  logic [RandWidth-1:0] decoy_entropy;
  assign decoy_entropy = perm_data(entropy_i[1], RndCnstRandPermDefault);
  assign dec_o = decoy_entropy;
  assign decoy_o = {DecoyCopies{decoy_entropy}};
endmodule
