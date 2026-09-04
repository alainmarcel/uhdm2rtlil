// Unpacked-array localparam declared INSIDE a generate scope, element-selected
// with constant and dynamic indices (Pavona/OT-config ibex_alu FLIP_MASK_L:
// the bit_select-on-parameter path only searched module-level Parameters and
// hard-errored "Could not find wire ... for bit select").
module genscope_param_table (
  input  logic [1:0]  sel,
  output logic [31:0] o_const,
  output logic [31:0] o_dyn,
  output logic [31:0] o_expr
);
  if (1) begin : g
    localparam logic [31:0] T [4] = '{32'h1100_0011, 32'h2200_0022,
                                      32'h3300_0033, 32'h4400_0044};
    assign o_const = T[2];
    assign o_dyn   = T[sel];
    assign o_expr  = ({30'b0, sel} << 4) & T[1];
  end
endmodule
