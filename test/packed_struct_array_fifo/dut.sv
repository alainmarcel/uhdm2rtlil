typedef struct packed {
  logic [3:0] op;
  logic [7:0] a;
} d_t;

module packed_struct_array_fifo #(
    parameter int unsigned DEPTH = 1,
    parameter type dtype = d_t,
    localparam int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic flush_i,
    input  logic push_i,
    input  logic pop_i,
    input  dtype data_i,
    output dtype data_o,
    output logic full_o,
    output logic empty_o
);
  localparam int unsigned FifoDepth = (DEPTH > 0) ? DEPTH : 1;
  logic [ADDR_DEPTH-1:0] read_pointer_n, read_pointer_q, write_pointer_n, write_pointer_q;
  logic [ADDR_DEPTH:0] status_cnt_n, status_cnt_q;
  dtype [FifoDepth-1:0] mem_n, mem_q;

  assign full_o  = (status_cnt_q == FifoDepth[ADDR_DEPTH:0]);
  assign empty_o = (status_cnt_q == 0);

  always_comb begin
    read_pointer_n  = read_pointer_q;
    write_pointer_n = write_pointer_q;
    status_cnt_n    = status_cnt_q;
    data_o          = mem_q[read_pointer_q];
    mem_n           = mem_q;

    if (push_i && ~full_o) begin
      mem_n[write_pointer_q] = data_i;
      if (write_pointer_q == FifoDepth[ADDR_DEPTH-1:0] - 1) write_pointer_n = '0;
      else write_pointer_n = write_pointer_q + 1;
      status_cnt_n = status_cnt_q + 1;
    end

    if (pop_i && ~empty_o) begin
      if (read_pointer_n == FifoDepth[ADDR_DEPTH-1:0] - 1) read_pointer_n = '0;
      else read_pointer_n = read_pointer_q + 1;
      status_cnt_n = status_cnt_q - 1;
    end

    if (push_i && pop_i && ~full_o && ~empty_o) status_cnt_n = status_cnt_q;

    if (flush_i) begin
      status_cnt_n    = '0;
      read_pointer_n  = '0;
      write_pointer_n = '0;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      read_pointer_q  <= '0;
      write_pointer_q <= '0;
      status_cnt_q    <= '0;
    end else begin
      read_pointer_q  <= read_pointer_n;
      write_pointer_q <= write_pointer_n;
      status_cnt_q    <= status_cnt_n;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      mem_q <= '0;
    end else begin
      mem_q <= mem_n;
    end
  end
endmodule
