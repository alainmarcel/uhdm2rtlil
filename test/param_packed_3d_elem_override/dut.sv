// A 3-D packed parameter's element, selected by two genvars, as a child
// parameter override -- rggen block_0 register 10:
//   parameter bit [3:0][3:0][1:0] REGISTER_10_BIT_FIELD_1_INITIAL_VALUE = {16{2'h0}},
//   ... .INITIAL_VALUE (REGISTER_10_BIT_FIELD_1_INITIAL_VALUE[i][j])
//
// The var_select has no wire behind it and (in the generate-scope copy) no
// Actual_group; read_uhdm's wire-centric element path looked for a wire
// `INIT[0]`, warned "vpiVarSelect: element not found", and every child took
// its DEFAULT reset value -- one paramod instead of four.  The parameter's
// constant is sliced by its typespec ranges now.  Reset values differ per
// element here (0..3 in a shuffled table) so a wrong slice shows.
module field #(parameter bit [1:0] INITIAL_VALUE = 2'h0) (
  input  logic       i_clk, i_rst_n, i_set,
  input  logic [1:0] i_val,
  output logic [1:0] o_val
);
  always_ff @(posedge i_clk or negedge i_rst_n)
    if (!i_rst_n)   o_val <= INITIAL_VALUE;
    else if (i_set) o_val <= i_val;
endmodule

module top #(
  parameter bit [3:0][3:0][1:0] INIT = {2'h0, 2'h1, 2'h2, 2'h3,  2'h3, 2'h2, 2'h1, 2'h0,  2'h1, 2'h1, 2'h1, 2'h1,  2'h2, 2'h2, 2'h2, 2'h2}
)(
  input  logic        i_clk, i_rst_n, i_set,
  input  logic [1:0]  i_val,
  output logic [3:0][3:0][1:0] o_val,
  output logic [3:0][3:0][1:0] o_val2,
  output logic [1:0]           o_top
);
  // the same override at MODULE level (no generate scope): a child of the
  // top is typed through the hierarchy signature builder, not import_module
  field #(.INITIAL_VALUE(INIT[1][2])) u_top (
    .i_clk(i_clk), .i_rst_n(i_rst_n), .i_set(i_set), .i_val(i_val), .o_val(o_top));
  genvar i, j;
  generate
    for (i = 0; i < 4; ++i) begin : g_i
      for (j = 0; j < 4; ++j) begin : g_j
        field #(.INITIAL_VALUE(INIT[i][j])) u_field (
          .i_clk(i_clk), .i_rst_n(i_rst_n), .i_set(i_set), .i_val(i_val), .o_val(o_val[i][j]));
      end
    end
    // rggen's other shape (block_0 register 10, bit field 2): a GENERATE-SCOPE
    // localparam carrying the child parameter's own NAME, element-selected.
    // The child's param_assign RHS is then this very select, and the table
    // lives on the generate scope, not on a module instance.
    for (i = 0; i < 4; ++i) begin : g_k
      for (j = 0; j < 4; ++j) begin : g_l
        localparam bit [3:0][3:0][1:0] INITIAL_VALUE = {2'h2, 2'h1, 2'h0, 2'h3,  2'h1, 2'h0, 2'h3, 2'h2,  2'h0, 2'h3, 2'h2, 2'h1,  2'h3, 2'h2, 2'h1, 2'h0};
        field #(.INITIAL_VALUE(INITIAL_VALUE[i][j])) u_field (
          .i_clk(i_clk), .i_rst_n(i_rst_n), .i_set(i_set), .i_val(i_val), .o_val(o_val2[i][j]));
      end
    end
  endgenerate
endmodule
