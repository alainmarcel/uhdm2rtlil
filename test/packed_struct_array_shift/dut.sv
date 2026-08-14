typedef struct packed {
  logic       valid;
  logic [7:0] ra;
} ras_t;

module packed_struct_array_shift (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       push_i,
    input  logic       pop_i,
    input  logic       flush_i,
    input  logic [7:0] data_i,
    output ras_t       data_o
);
  localparam DEPTH = 2;
  ras_t [DEPTH-1:0] stack_d, stack_q;

  assign data_o = stack_q[0];

  always_comb begin
    stack_d = stack_q;
    if (push_i) begin
      stack_d[0].ra = data_i;
      stack_d[0].valid = 1'b1;
      stack_d[DEPTH-1:1] = stack_q[DEPTH-2:0];
    end
    if (pop_i) begin
      stack_d[DEPTH-2:0] = stack_q[DEPTH-1:1];
      stack_d[DEPTH-1].valid = 1'b0;
      stack_d[DEPTH-1].ra = 'b0;
    end
    if (pop_i && push_i) begin
      stack_d = stack_q;
      stack_d[0].ra = data_i;
      stack_d[0].valid = 1'b1;
    end
    if (flush_i) begin
      stack_d = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      stack_q <= '0;
    end else begin
      stack_q <= stack_d;
    end
  end
endmodule
