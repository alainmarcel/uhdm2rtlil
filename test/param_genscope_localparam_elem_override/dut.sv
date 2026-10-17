// A child's parameter override selected from a GENERATE-SCOPE localparam that
// carries the child parameter's OWN NAME -- rggen block_0's register_10
// bit_field_2:
//
//     for (j = 0;j < 4;++j) begin : g
//       localparam bit [3:0][3:0][1:0] INITIAL_VALUE = {...};
//       rggen_bit_field #(.INITIAL_VALUE(INITIAL_VALUE[i][j])) u_bit_field (...);
//
// The override is folded with the CHILD as the context, and the child has a
// parameter of that name too (`bit [WIDTH-1:0] INITIAL_VALUE`).  The fold
// took the child's own 2-bit default as the table, whose single range cannot
// take two indices, fell through, and the paramod's parameter was stored
// EMPTY: every field reset to 0 while the paramod NAME (folded in the
// parent, where no such parameter exists) carried the right value.
//
// Only this path: test/param_packed_3d_elem_override also instantiates the
// same paramods through a MODULE-level parameter, which creates them with
// the right value first, so the generate-scope half was never measured on
// its own there.
module field #(
  parameter int             WIDTH         = 8,
  parameter bit [WIDTH-1:0] INITIAL_VALUE = '0
) (
  input  logic             i_clk, i_rst_n, i_set,
  input  logic [WIDTH-1:0] i_val,
  output logic [WIDTH-1:0] o_val
);
  always_ff @(posedge i_clk, negedge i_rst_n)
    if (!i_rst_n) o_val <= INITIAL_VALUE;
    else if (i_set) o_val <= i_val;
endmodule

module top (
  input  logic                 i_clk, i_rst_n, i_set,
  input  logic [1:0]           i_val,
  output logic [3:0][3:0][1:0] o_val
);
  generate if (1) begin : g_register_10
    genvar i;
    for (i = 0; i < 4; ++i) begin : g
      if (1) begin : g_bit_field_2
        genvar j;
        for (j = 0; j < 4; ++j) begin : g
          localparam bit [3:0][3:0][1:0] INITIAL_VALUE =
            {2'h2, 2'h1, 2'h0, 2'h3,  2'h1, 2'h0, 2'h3, 2'h2,
             2'h0, 2'h3, 2'h2, 2'h1,  2'h3, 2'h2, 2'h1, 2'h0};
          field #(
            .WIDTH         (2),
            .INITIAL_VALUE (INITIAL_VALUE[i][j])
          ) u_bit_field (
            .i_clk   (i_clk),
            .i_rst_n (i_rst_n),
            .i_set   (i_set),
            .i_val   (i_val),
            .o_val   (o_val[i][j])
          );
        end
      end
    end
  end endgenerate
endmodule
