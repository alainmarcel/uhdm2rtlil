// A package S-box TABLE read UNQUALIFIED from inside the package's own
// function, which the module calls by its QUALIFIED name with no wildcard
// import (OpenTitan prim_present -> prim_cipher_pkg::present_update_key128:
// `key_out[127 -: 4] = PRESENT_SBOX4[key_out[127 -: 4]]`).  The bit_select
// links to the package parameter, whose folded value is keyed `pkg::SBOX4`;
// the bare-name lookup missed and read_uhdm aborted with "Could not find
// wire 'PRESENT_SBOX4' for bit select" on the OpenTitan Egret top.
package pkg_table_unqualified_in_pkg_function_pkg;
  parameter logic [15:0][3:0] SBOX4 = {4'h2, 4'h1, 4'h7, 4'h4,
                                       4'h8, 4'hF, 4'hE, 4'h3,
                                       4'hD, 4'hA, 4'h0, 4'h9,
                                       4'hB, 4'h6, 4'h5, 4'hC};
  function automatic logic [15:0] update_key(logic [15:0] key_in, logic [3:0] rnd);
    logic [15:0] key_out;
    key_out = {key_in[4:0], key_in[15:5]};
    key_out[15 -: 4] = SBOX4[key_out[15 -: 4]];
    key_out[11 -: 4] = SBOX4[key_out[11 -: 4]];
    key_out[6:3] ^= rnd;
    return key_out;
  endfunction
endpackage
module pkg_table_unqualified_in_pkg_function (
  input  logic        clk_i,
  input  logic [15:0] key_i,
  input  logic [3:0]  rnd_i,
  output logic [15:0] key_o,
  output logic [15:0] key_q
);
  // Qualified calls, NO wildcard import (as prim_present does): the table is
  // then only reachable through the package, under its `pkg::NAME` key.
  assign key_o = pkg_table_unqualified_in_pkg_function_pkg::update_key(key_i, rnd_i);
  always_ff @(posedge clk_i) key_q <= pkg_table_unqualified_in_pkg_function_pkg::update_key(key_q ^ key_i, rnd_i);
endmodule
