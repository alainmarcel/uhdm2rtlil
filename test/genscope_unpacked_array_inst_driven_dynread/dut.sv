// An unpacked array declared INSIDE an if-generate block, driven element by
// element through child-instance output ports in a nested genvar loop, and
// read with a dynamic index from a further nested if-generate (lowRISC
// ibex_cs_registers' debug triggers, DbgTriggerEn=1 as in the OpenTitan Egret
// top: `logic [31:0] tmatch_value_q[DbgHwBreakNum]; ... .rd_data_o
// (tmatch_value_q[i]) ... assign selected_tmatch_value =
// tmatch_value_q[tselect_q];`).  read_uhdm aborted with "Could not find wire
// 'tmatch_value_q' for bit select".
module genscope_unpacked_array_inst_driven_dynread_reg #(parameter int W = 8) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic [W-1:0] d_i,
  input  logic         we_i,
  output logic [W-1:0] q_o
);
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) q_o <= '0;
    else if (we_i) q_o <= d_i;
endmodule

module genscope_unpacked_array_inst_driven_dynread #(parameter bit En = 1, parameter int N = 4) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic [7:0]  d_i,
  input  logic [1:0]  wsel_i,
  input  logic        we_i,
  input  logic [1:0]  rsel_i,
  output logic [7:0]  q_o,
  output logic [7:0]  q0_o
);
  if (En) begin : gen_regs
    logic [7:0] val_q [N];
    for (genvar i = 0; i < N; i++) begin : g_reg
      genscope_unpacked_array_inst_driven_dynread_reg #(.W(8)) u_reg (
        .clk_i, .rst_ni, .d_i,
        .we_i (we_i && (wsel_i == i[1:0])),
        .q_o  (val_q[i])
      );
    end
    if (N > 1) begin : g_multi
      assign q_o = val_q[rsel_i];
    end else begin : g_single
      assign q_o = val_q[0];
    end
    assign q0_o = val_q[0];
  end else begin : gen_none
    assign q_o = '0;
    assign q0_o = '0;
  end
endmodule
