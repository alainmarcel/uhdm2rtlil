// Array indices given by a hierarchical reference to a localparam declared in
// another named generate block (ACC acc_alu_bignum:
// `ispr_rdata_intg_mux_in[gen_ispr_ids_pqc.IsprKmacMsg0Intg] = ...`).
module genscope_hier_localparam_array_index #(
  parameter bit En = 1'b1
) (
  input  logic [7:0] a_i,
  input  logic [7:0] b_i,
  input  logic [7:0] c_i,
  input  logic [1:0] sel_i,
  output logic [7:0] y0_o,
  output logic [7:0] y1_o,
  output logic [7:0] y2_o,
  output logic [7:0] ysel_o,
  output logic [2:0] onehot_o
);
  logic [7:0] mux_in [3];
  logic [2:0] mux_sel;

  if (En) begin : gen_ids
    localparam int IdB = 1;
    localparam int IdC = 2;
  end

  assign mux_in[0]  = a_i;
  assign mux_sel[0] = (sel_i == 2'd0);

  if (En) begin : gen_mux
    assign mux_in[gen_ids.IdB]  = b_i;
    assign mux_in[gen_ids.IdC]  = c_i;
    assign mux_sel[gen_ids.IdB] = (sel_i == 2'd1);
    assign mux_sel[gen_ids.IdC] = (sel_i == 2'd2);
  end

  assign y0_o     = mux_in[0];
  assign y1_o     = mux_in[1];
  assign y2_o     = mux_in[2];
  assign ysel_o   = (sel_i < 2'd3) ? mux_in[sel_i] : 8'h00;
  assign onehot_o = mux_sel;
endmodule
