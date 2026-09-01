// Three dynamic packed-write shapes from CVA6's hpdcache data path:
//  1. `buf_q[wrptr][word] <= wdata` — TWO dynamic indexes on a multi-dim
//     packed array: the second index selected a BIT instead of a WORD
//     (hpdcache_data_upsize stored 1 of 64 bits).
//  2. `words_d[wrptr] = ...` on a 1x1-bit array (DEPTH=1): the
//     "plain vector" bail dropped the write outright.
//  3. `fifo_mem_q[wptr] <= wdata` on a GEN-SCOPE array in a type-param'd
//     fifo: the bare-name wire lookup failed, the LHS fell to the READ
//     import and the store vanished (hpdcache_fifo_reg).
module upsz #(
    parameter int WR_WIDTH = 0,
    parameter int RD_WIDTH = 0,
    localparam type wdata_t = logic [WR_WIDTH-1:0],
    localparam type rdata_t = logic [RD_WIDTH-1:0]
) (
    input  logic   clk_i,
    input  logic   rst_ni,
    input  logic   w_i,
    input  wdata_t wdata_i,
    input  logic   r_i,
    output rdata_t rdata_o,
    output logic   rok_o
);
  localparam int WR_WORDS = RD_WIDTH / WR_WIDTH;
  wdata_t [0:0][WR_WORDS-1:0] buf_q;
  logic [0:0] words_q, words_d;
  logic       full_q;

  always_comb begin
    words_d = words_q;
    if (w_i && !full_q) words_d[1'b0] = words_q[1'b0] + 1'b1;
    if (r_i && full_q)  words_d[1'b0] = 1'b0;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buf_q <= '0; words_q <= '0; full_q <= 1'b0;
    end else begin
      words_q <= words_d;
      if (w_i && !full_q) begin
        buf_q[1'b0][words_q[1'b0]] <= wdata_i;
        if (words_q[1'b0] == WR_WORDS - 1) full_q <= 1'b1;
      end else if (r_i && full_q) full_q <= 1'b0;
    end
  end
  assign rdata_o = buf_q[1'b0];
  assign rok_o = full_q;
endmodule

module gfifo #(
    parameter int unsigned FIFO_DEPTH = 0,
    parameter type fifo_data_t = logic
) (
    input  logic       clk_i,
    input  logic       rst_ni,
    input  logic       w_i,
    input  fifo_data_t wdata_i,
    input  logic       r_i,
    output fifo_data_t rdata_o,
    output logic       rok_o
);
  if (FIFO_DEPTH > 1) begin : gen_fifo
    fifo_data_t [FIFO_DEPTH-1:0] fifo_mem_q;
    logic [1:0] wptr_q, rptr_q;
    logic [2:0] cnt_q;
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        fifo_mem_q <= '0; wptr_q <= '0; rptr_q <= '0; cnt_q <= '0;
      end else begin
        if (w_i && cnt_q < FIFO_DEPTH) begin
          fifo_mem_q[wptr_q] <= wdata_i;
          wptr_q <= wptr_q + 1'b1;
          cnt_q <= cnt_q + {2'b0, ~(r_i && cnt_q != 0)};
        end else if (r_i && cnt_q != 0) cnt_q <= cnt_q - 1'b1;
        if (r_i && cnt_q != 0) rptr_q <= rptr_q + 1'b1;
      end
    end
    assign rdata_o = fifo_mem_q[rptr_q];
    assign rok_o = (cnt_q != 0);
  end
endmodule

module genscope_fifo_dyn_write (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        w_i,
    input  logic [15:0] wdata_i,
    input  logic        r_i,
    output logic [31:0] up_rdata_o,
    output logic        up_rok_o,
    output logic [15:0] ff_rdata_o,
    output logic        ff_rok_o
);
  upsz #(.WR_WIDTH(16), .RD_WIDTH(32)) u_up (
    .clk_i, .rst_ni, .w_i, .wdata_i, .r_i,
    .rdata_o(up_rdata_o), .rok_o(up_rok_o));
  gfifo #(.FIFO_DEPTH(4), .fifo_data_t(logic [15:0])) u_ff (
    .clk_i, .rst_ni, .w_i, .wdata_i, .r_i,
    .rdata_o(ff_rdata_o), .rok_o(ff_rok_o));
endmodule
