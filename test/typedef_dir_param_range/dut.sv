// Module-scope typedef whose packed dim is PARAMETER arithmetic
// (`typedef entry_t [Entries-1:0] dir_t`): Surelog folded the range with the
// DEFAULT config ('0 -> [-1:0]) at bindTypedefs_ time and shared the stamp
// with every instance — hpdcache_flush's 8-entry directory collapsed to 2
// entries (104 vs 416 bits) and both the genvar reads `dir_q[gen_i].nline`
// and the dynamic read `dir_q[ack_ptr].nline` were dropped.
module flushdir #(
    parameter int unsigned Entries = 0,
    parameter int unsigned W = 0
) (
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             alloc_i,
    input  logic [W-1:0]     nline_i,
    input  logic [2:0]       ack_ptr_i,
    input  logic [W-1:0]     chk_i,
    output logic [W-1:0]     ack_nline_o,
    output logic [7:0]       hit_o
);
  typedef struct packed {
    logic [W-1:0] nline;
  } entry_t;
  typedef entry_t [Entries-1:0] dir_t;

  dir_t             dir_q;
  logic [Entries-1:0] vld_q;
  logic [2:0]       wptr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dir_q  <= '0;
      vld_q  <= '0;
      wptr_q <= '0;
    end else if (alloc_i) begin
      dir_q[wptr_q] <= '{nline: nline_i};
      vld_q[wptr_q] <= 1'b1;
      wptr_q <= wptr_q + 1;
    end
  end

  // Dynamic element + field read.
  assign ack_nline_o = dir_q[ack_ptr_i].nline;

  // Genvar element + field reads.
  for (genvar gen_i = 0; gen_i < int'(Entries); gen_i++) begin : gen_chk
    assign hit_o[gen_i] = vld_q[gen_i] & (chk_i == dir_q[gen_i].nline);
  end
endmodule

module typedef_dir_param_range (
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        alloc_i,
    input  logic [12:0] nline_i,
    input  logic [2:0]  ack_ptr_i,
    input  logic [12:0] chk_i,
    output logic [12:0] ack_nline_o,
    output logic [7:0]  hit_o
);
  flushdir #(.Entries(8), .W(13)) u_dir (.*);
endmodule
