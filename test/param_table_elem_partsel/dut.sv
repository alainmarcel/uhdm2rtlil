// Constant element + part select of an UNPACKED localparam table
// (prim_lfsr's LFSR_COEFFS[LfsrDw-LUT_OFF][LfsrDw-1:0] evaluated to 0 on the
// UHDM side, collapsing the Galois feedback and every ibex dummy-instruction
// LFSR).
module param_table_elem_partsel (
  input  logic [2:0]  sel,
  output logic [31:0] c_const,
  output logic [31:0] c_dyn
);
  localparam int unsigned W = 32;
  localparam int unsigned OFF = 3;
  localparam logic [39:0] T [8] = '{40'h6, 40'hC, 40'h14, 40'h30, 40'h60, 40'hB8, 40'h110, 40'h240};
  // constant index (the prim_lfsr shape)
  assign c_const = T[W/8 - OFF][W-1:0];
  // dynamic index for coverage
  assign c_dyn   = T[sel][W-1:0];
endmodule
