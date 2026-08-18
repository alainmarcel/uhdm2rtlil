// The shapes wt_dcache_mem's p_bank_req block is built from:
//   - 2-D packed inputs indexed by a REGISTERED selector  (rd_off_i[vld_sel_d])
//   - a part-select of such an element, inside a for loop (bank_collision[k])
//   - an unpacked array written at a COMPUTED dynamic index (bank_idx[...])
//   - an output gated on a dynamic bit-select of a vector written earlier in
//     the same always_comb
module dut #(
    parameter int unsigned NumPorts = 4,
    parameter int unsigned OFF_W    = 6,
    parameter int unsigned IDX_W    = 8,
    parameter int unsigned ALIGN    = 3
) (
    input  logic                              clk_i,
    input  logic                              rst_ni,
    input  logic [NumPorts-1:0][OFF_W-1:0]    rd_off_i,
    input  logic [NumPorts-1:0][IDX_W-1:0]    rd_idx_i,
    input  logic [NumPorts-1:0]               rd_req_i,
    input  logic [NumPorts-1:0]               rd_tag_only_i,
    input  logic [NumPorts-1:0]               rd_ack_i,
    input  logic [OFF_W-1:0]                  wr_off_i,
    input  logic                              wr_req_i,
    output logic                              wr_ack_o,
    output logic [IDX_W-1:0]                  bank_idx_o,
    output logic [NumPorts-1:0]               bank_req_o
);
  localparam int SEL_W = $clog2(NumPorts);
  logic [SEL_W-1:0]  vld_sel_d, vld_sel_q;
  logic [NumPorts-1:0] bank_collision;
  logic [NumPorts-1:0][IDX_W-1:0] bank_idx;

  // a registered selector, like vld_sel_q
  assign vld_sel_d = rd_req_i[0] ? SEL_W'(1) : SEL_W'(2);
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) vld_sel_q <= '0;
    else         vld_sel_q <= vld_sel_d;

  always_comb begin
    bank_req_o = '0;
    wr_ack_o   = 1'b0;
    bank_idx   = '{default: rd_idx_i[vld_sel_q]};

    for (int k = 0; k < NumPorts; k++)
      bank_collision[k] = rd_off_i[k][OFF_W-1:ALIGN] == wr_off_i[OFF_W-1:ALIGN];

    if (|rd_req_i) begin
      // write at a COMPUTED dynamic index
      bank_idx[rd_off_i[vld_sel_q][OFF_W-1:ALIGN]] = rd_idx_i[vld_sel_q];
      bank_req_o[vld_sel_q] = 1'b1;
    end

    if (wr_req_i) begin
      if (rd_tag_only_i[vld_sel_q] ||
          !(rd_ack_i[vld_sel_q] && bank_collision[vld_sel_q])) begin
        wr_ack_o = 1'b1;
      end
    end
  end

  assign bank_idx_o = bank_idx[vld_sel_q];
endmodule
