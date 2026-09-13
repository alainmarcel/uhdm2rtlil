// sha3pad with EnMasking=0: a ONE-element unpacked array reset whole
// ('{default:'0}) and written per element in an unrolled loop.  `buf_q[0]`
// is the same width as `buf_q`, so the per-element temp must be dropped in
// favour of the flat one (else proc_arst: "async reset yields non-constant").
module ff_share1_array_reset_elem_loop(input logic clk, input logic rst_n, input logic [55:0] df, input logic en, input logic clr,
         output logic [55:0] qf);
  localparam int Share = 1;
  logic [55:0] buf_q [Share];
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buf_q <= '{default:'0};
    end else if (en) begin
      for (int i = 0; i < Share; i++) begin
        buf_q[i] <= df[i*56 +: 56];
      end
    end else if (clr) begin
      buf_q <= '{default:'0};
    end
  end
  assign qf = buf_q[0];
endmodule
