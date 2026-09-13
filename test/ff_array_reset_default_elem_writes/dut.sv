module ff_array_reset_default_elem_writes(input logic clk, input logic rst_n, input logic [111:0] df, input logic en, input logic clr,
         output logic [111:0] qf);
  localparam int Share = 2;
  logic [55:0] buf_q [Share];
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      buf_q <= '{default:'0};
    end else if (clr) begin
      buf_q <= '{default:'0};
    end else if (en) begin
      for (int i = 0; i < Share; i++) begin
        buf_q[i] <= df[i*56 +: 56];
      end
    end
  end
  assign qf = {buf_q[1], buf_q[0]};
endmodule
