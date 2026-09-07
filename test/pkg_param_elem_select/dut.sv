// Regression: element-select of a PACKAGE array/table parameter
// `pkg::TABLE[idx]` (both constant and dynamic index).  Surelog leaves the
// elaborated bit_select's Actual_group null and the parameter lives in a
// package (not the module's Parameters()), so the frontend used to fail with
// "Could not find wire 'pkg::TABLE' for bit select".  Modelled on ibex's
// prim_present / prim_subst_perm indexing prim_cipher_pkg::PRESENT_SBOX4.
package sbox_pkg;
  parameter logic [15:0][3:0] SBOX4 = {4'h2, 4'h1, 4'h7, 4'h4,
                                       4'h8, 4'hF, 4'hE, 4'h3,
                                       4'hD, 4'hA, 4'h0, 4'h9,
                                       4'hB, 4'h6, 4'h5, 4'hC};
endpackage

module pkg_param_elem_select (
  input  logic [3:0] idx_dyn,
  output logic [3:0] o_dyn,     // dynamic index
  output logic [3:0] o_const    // constant index
);
  assign o_dyn   = sbox_pkg::SBOX4[idx_dyn];
  assign o_const = sbox_pkg::SBOX4[4'd10];   // must be 4'h0 (11th entry)
endmodule
