// A comb block INSIDE A GENERATE SCOPE that writes a variable declared in that
// scope whole (`vd = vq`) and then through a select (`vd[8 +: 8] = v_i`, and
// the dynamic `vd[pq*8 +: 8] = v_i`).  The select targets must resolve to the
// scoped wire `gen_x.vd`: registered under the bare `vd`, the static write got
// its own ranged `$0\gen_x.vd[15:8]` temp with a self-hold default next to the
// full `$0\gen_x.vd` (two STa updates on the same bits, the clear never
// reached the slice), and the dynamic write's emitter did not find its base
// at all and the write landed on a fresh unconnected wire -- snitch
// spatz_vfu's gen_pipeline_ipu `ipu_result_valid_d[ipu_result_pnt_q*ELENB*N_IPU
// +: ELENB*N_IPU] = int_ipu_result_valid` never set a valid (170 diverging
// co-simulated cycles).  At module level both shapes were already right.
// The write fires on `v_i[0]` so random stimulus exercises it every other
// cycle (an all-ones guard left the co-sim vacuous).
module dut #(parameter int N_FU = 2, parameter int N_IPU = 1, parameter int ELENB = 8) (
  input  logic                   clk_i,
  input  logic                   rst_ni,
  input  logic [N_IPU*ELENB-1:0] v_i,
  input  logic                   ready_i,
  input  logic                   sel_i,
  output logic [N_FU*ELENB-1:0]  valid_dyn_o,
  output logic [N_FU*ELENB-1:0]  valid_const_o
);
  if (N_IPU < N_FU) begin: gen_dyn
    logic [N_FU*ELENB-1:0] vq, vd;
    logic [$clog2(N_FU/N_IPU)-1:0] pq, pd;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin vq <= '0; pq <= '0; end
      else begin vq <= vd; pq <= pd; end
    end
    always_comb begin
      vd = vq;
      pd = pq;
      if (ready_i) vd = '0;
      if (v_i[0]) begin
        vd[pq*ELENB*N_IPU +: ELENB*N_IPU] = v_i;   // dynamic offset
        pd = pq + 1;
      end
    end
    assign valid_dyn_o = vq;
  end
  if (N_IPU < N_FU) begin: gen_const
    logic [N_FU*ELENB-1:0] vq, vd;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) vq <= '0;
      else vq <= vd;
    end
    always_comb begin
      vd = vq;
      if (ready_i) vd = '0;
      if (v_i[0]) begin                                    // constant offsets
        if (sel_i) vd[ELENB*N_IPU +: ELENB*N_IPU] = v_i;
        else       vd[0 +: ELENB*N_IPU]           = ~v_i;
      end
    end
    assign valid_const_o = vq;
  end
endmodule
