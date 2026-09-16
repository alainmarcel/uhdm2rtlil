// Shift register written as `q <= {q[0 +: N-1], 1'b1}` in an async-reset
// always_ff, N a parameter overridden by the parent (OpenTitan rstmgr_por's
// power-on-reset filter).  read_uhdm kept the filter from ever filling, so the
// Egret chip never released its power-on reset.
module ff_shift_indexed_partsel_param_width_child #(
  parameter int FilterStages = 3
) (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  output logic [FilterStages-1:0] filter_o,
  output logic                    stable_o
);
  logic [FilterStages-1:0] rst_filter_n;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rst_filter_n <= '0;
    end else begin
      rst_filter_n <= {rst_filter_n[0 +: FilterStages-1], 1'b1};
    end
  end
  assign filter_o = rst_filter_n;
  assign stable_o = &rst_filter_n;
endmodule

module ff_shift_indexed_partsel_param_width (
  input  logic       clk_i,
  input  logic       rst_ni,
  output logic [1:0] f2_o,
  output logic [2:0] f3_o,
  output logic [3:0] f4_o,
  output logic [2:0] stable_o,
  output logic [2:0] g0_o,
  output logic [2:0] g1_o
);
  ff_shift_indexed_partsel_param_width_child #(.FilterStages(2)) u_f2 (
    .clk_i, .rst_ni, .filter_o(f2_o), .stable_o(stable_o[0]));
  ff_shift_indexed_partsel_param_width_child u_f3 (
    .clk_i, .rst_ni, .filter_o(f3_o), .stable_o(stable_o[1]));
  ff_shift_indexed_partsel_param_width_child #(.FilterStages(4)) u_f4 (
    .clk_i, .rst_ni, .filter_o(f4_o), .stable_o(stable_o[2]));

  // Default-parameter child inside a nested generate (rstmgr's
  // gen_rst_por_aon[i].gen_rst_por_aon_normal.u_rst_por_aon).
  logic [2:0] g_filter [2];
  for (genvar i = 0; i < 2; i++) begin : gen_por
    if (i == 0) begin : gen_normal
      ff_shift_indexed_partsel_param_width_child u_por (
        .clk_i, .rst_ni, .filter_o(g_filter[i]), .stable_o());
    end else begin : gen_other
      ff_shift_indexed_partsel_param_width_child u_por (
        .clk_i, .rst_ni, .filter_o(g_filter[i]), .stable_o());
    end
  end
  assign g0_o = g_filter[0];
  assign g1_o = g_filter[1];
endmodule
