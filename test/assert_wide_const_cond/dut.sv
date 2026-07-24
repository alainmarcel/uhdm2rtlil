// Reproducer for CVA6 axi_shim "$check cell error": an immediate assert whose
// condition is a struct-parameter-field comparison (`Cfg.W >= 2`) that folds to
// a WIDE (64-bit) constant.  $check's A port must be 1-bit — build_check_cell
// must reduce the condition.
package cfg_pkg;
  typedef struct packed { int unsigned W; } cfg_t;
  localparam cfg_t DefaultCfg = '{W: 32'd4};
endpackage

module assert_wide_const_cond #(
    parameter cfg_pkg::cfg_t Cfg = cfg_pkg::DefaultCfg
) (
    input logic clk_i,
    input logic a_i,
    output logic o_o
);
  initial begin
    assert (Cfg.W) else $error("W must be nonzero");
  end
  assign o_o = a_i;
endmodule
