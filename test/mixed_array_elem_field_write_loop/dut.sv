typedef struct packed { logic SDTRIG; logic X64; } cfg_t;
typedef struct packed { logic [3:0] mh; logic [1:0] z; logic [3:0] a; logic [3:0] b; logic [1:0] s; } t64;
typedef struct packed { logic [1:0] z; logic [3:0] a; logic [1:0] s; } t32;
module dut #(parameter cfg_t CFG = '{SDTRIG: 1'b1, X64: 1'b1}) (input clk, input rst_ni, input [1:0] sel_i, input sel_we, input we, input [15:0] din, output logic [15:0] o);
  t64 q64[4], d64[4];
  t32 q32[4], d32[4];
  logic [1:0] sel_q, sel_d;
  logic [31:0] din_64;
  assign din_64 = {16'b0, din};
  always_comb begin : write_path
    sel_d = sel_q;
    for (int i = 0; i < 4; i++) begin
      d32[i] = q32[i];
      d64[i] = q64[i];
    end
    if (sel_we) sel_d = sel_i;
    if (we) begin
      if (!CFG.X64) begin
        d32[sel_q].z = '0;
        d32[sel_q].a = din[7:4];
        d32[sel_q].s = din[1:0];
      end
      if (CFG.X64) begin
        d64[sel_q].mh = '0;
        d64[sel_q].z  = '0;
        d64[sel_q].a  = din_64[11:8];
        d64[sel_q].b  = din_64[7:4];
        d64[sel_q].s  = din[1:0];
      end
    end
  end
  always_ff @(posedge clk or negedge rst_ni) begin : state_update
    if (!rst_ni) begin
      sel_q <= '0;
      for (int i = 0; i < 4; i++) begin q32[i] <= '0; q64[i] <= '0; end
    end else begin
      if (CFG.SDTRIG) begin
        sel_q <= sel_d;
        q32 <= d32;
        q64 <= d64;
      end
    end
  end
  if (!CFG.X64) begin : g32
    always_comb o = {8'b0, q32[sel_q]};
  end else begin : g64
    always_comb o = q64[sel_q];
  end
endmodule
