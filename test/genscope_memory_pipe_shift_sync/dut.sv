// A GENERATE-scope memory shifted through a read pipeline in a clocked
// block:  for (j = PIPELINE-1; j > 0; j--) if (ready || ((~valid) >> j))
//           rd_resp_data_pipe_reg[j] <= rd_resp_data_pipe_reg[j-1];
// next to a byte-enabled RAM written in another block (verilog-pcie
// dma_psdpram).  The block goes through the legacy sync path (memory write
// inside a for loop), whose memory-write branch looked the memory up by its
// BARE name: a generate-scope memory is registered as
// `genblk1[0].rd_resp_data_pipe_reg`, so the lookup missed, the write fell
// to the generic path and was stored on a $memrd DATA wire — the pipeline
// never moved data and rd_resp_data stayed zero.  The module-scope twin was
// fine (gen-scope parity gap); the sync path now resolves the scoped name
// like the comb-style path already did.
module genscope_memory_pipe_shift_sync #(parameter SEG_COUNT = 2, parameter SEG_DATA_WIDTH = 128, parameter SEG_BE_WIDTH = SEG_DATA_WIDTH/8, parameter SEG_ADDR_WIDTH = 4) (
  input logic clk, input logic rst,
  input logic [SEG_COUNT*SEG_BE_WIDTH-1:0] wr_cmd_be, input logic [SEG_COUNT*SEG_ADDR_WIDTH-1:0] wr_cmd_addr, input logic [SEG_COUNT*SEG_DATA_WIDTH-1:0] wr_cmd_data, input logic [SEG_COUNT-1:0] wr_cmd_valid,
  output logic [SEG_COUNT-1:0] wr_done,
  input logic [SEG_COUNT*SEG_ADDR_WIDTH-1:0] rd_cmd_addr, input logic [SEG_COUNT-1:0] rd_cmd_valid, input logic [SEG_COUNT-1:0] rd_resp_ready, output logic [SEG_COUNT-1:0] rd_resp_valid, output logic [SEG_COUNT*SEG_DATA_WIDTH-1:0] rd_resp_data);
  localparam PIPELINE = 2;
  localparam INT_ADDR_WIDTH = 3;
  genvar n;
  generate
    for (n = 0; n < SEG_COUNT; n = n + 1) begin
      reg [SEG_DATA_WIDTH-1:0] mem_reg[2**INT_ADDR_WIDTH-1:0];
      reg wr_done_reg = 1'b0;
      reg [PIPELINE-1:0] rd_resp_valid_pipe_reg = 0;
      reg [SEG_DATA_WIDTH-1:0] rd_resp_data_pipe_reg[PIPELINE-1:0];
      wire rd_cmd_ready = rd_resp_ready[n] || ~rd_resp_valid_pipe_reg;
      always @(posedge clk) begin
        wr_done_reg <= 1'b0;
        for (int i = 0; i < SEG_BE_WIDTH; i = i + 1) begin
          if (wr_cmd_valid[n] && wr_cmd_be[n*SEG_BE_WIDTH+i]) begin
            mem_reg[wr_cmd_addr[SEG_ADDR_WIDTH*n +: INT_ADDR_WIDTH]][i*8 +: 8] <= wr_cmd_data[SEG_DATA_WIDTH*n+i*8 +: 8];
          end
          wr_done_reg <= wr_cmd_valid[n];
        end
        if (rst) wr_done_reg <= 1'b0;
      end
      assign wr_done[n] = wr_done_reg;
      always @(posedge clk) begin
        if (rd_resp_ready[n]) rd_resp_valid_pipe_reg[PIPELINE-1] <= 1'b0;
        for (int j = PIPELINE-1; j > 0; j = j - 1) begin
          if (rd_resp_ready[n] || ((~rd_resp_valid_pipe_reg) >> j)) begin
            rd_resp_valid_pipe_reg[j] <= rd_resp_valid_pipe_reg[j-1];
            rd_resp_data_pipe_reg[j] <= rd_resp_data_pipe_reg[j-1];
            rd_resp_valid_pipe_reg[j-1] <= 1'b0;
          end
        end
        if (rd_cmd_valid[n] && rd_cmd_ready) begin
          rd_resp_valid_pipe_reg[0] <= 1'b1;
          rd_resp_data_pipe_reg[0] <= mem_reg[rd_cmd_addr[SEG_ADDR_WIDTH*n +: INT_ADDR_WIDTH]];
        end
        if (rst) rd_resp_valid_pipe_reg <= 0;
      end
      assign rd_resp_valid[n] = rd_resp_valid_pipe_reg[PIPELINE-1];
      assign rd_resp_data[SEG_DATA_WIDTH*n +: SEG_DATA_WIDTH] = rd_resp_data_pipe_reg[PIPELINE-1];
    end
  endgenerate
endmodule
