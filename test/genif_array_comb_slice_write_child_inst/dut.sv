// Unpacked [Share] arrays declared INSIDE an if-generate block, written per
// word by always_comb blocks in nested generate loops, registered under an
// async reset, with a child module instantiated in the same block
// (OpenTitan-family ACC acc_alu_bignum gen_pqc_wsr: kmac_msg_intg_d /
// kmac_msg_no_intg_d).
module genif_array_comb_slice_write_child_and #(parameter int Width = 1) (
  input  logic [Width-1:0] a_i,
  input  logic [Width-1:0] b_i,
  output logic [Width-1:0] y_o
);
  assign y_o = a_i & b_i;
endmodule

module genif_array_comb_slice_write_child_inst #(
  parameter bit Enable = 1'b1,
  parameter int Share  = 2,
  parameter int Words  = 3
) (
  input  logic                clk_i,
  input  logic                rst_ni,
  input  logic [Words-1:0]    wr_en0_i,
  input  logic [Words-1:0]    wr_en1_i,
  input  logic [Words*8-1:0]  wdata_i,
  input  logic [Words*8-1:0]  mask_i,
  output logic [Words*8-1:0]  q0_o,
  output logic [Words*8-1:0]  q1_o,
  output logic [Words*4-1:0]  lo0_o,
  output logic [Words*8-1:0]  r0_o,
  output logic [Words*8-1:0]  r1_o
);
  if (Enable) begin : gen_wsr
    logic [Words*8-1:0] d      [Share];
    logic [Words*4-1:0] d_lo   [Share];
    logic [Words*8-1:0] q      [Share];
    logic [Words*8-1:0] masked;

    genif_array_comb_slice_write_child_and #(.Width(Words*8)) u_and (
      .a_i(wdata_i), .b_i(mask_i), .y_o(masked)
    );

    for (genvar w = 0; w < Words; w++) begin : g_word0
      always_comb begin
        d_lo[0][w*4+:4] = '0;
        d[0][w*8+:8]    = q[0][w*8+:8];
        if (wr_en0_i[w]) begin
          d_lo[0][w*4+:4] = masked[w*8+:4];
          d[0][w*8+:8]    = masked[w*8+:8];
        end
      end
    end

    for (genvar w = 0; w < Words; w++) begin : g_word1
      always_comb begin
        d_lo[1][w*4+:4] = '1;
        d[1][w*8+:8]    = '0;
        if (wr_en1_i[w]) begin
          d[1][w*8+:8] = ~wdata_i[w*8+:8];
        end
      end
    end

    for (genvar s = 0; s < Share; s++) begin : g_reg
      always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) q[s] <= '0;
        else         q[s] <= d[s];
      end
    end

    // Per-share, per-word enabled registers WITHOUT reset, written as element
    // slices from always_ff blocks in two separate generate loops.
    logic [Words*8-1:0] r [Share];
    for (genvar w = 0; w < Words; w++) begin : g_r0
      always_ff @(posedge clk_i) begin
        if (wr_en0_i[w]) begin
          r[0][w*8+:8] <= d[0][w*8+:8];
        end
      end
    end
    for (genvar w = 0; w < Words; w++) begin : g_r1
      always_ff @(posedge clk_i) begin
        if (wr_en1_i[w]) begin
          r[1][w*8+:8] <= d[1][w*8+:8];
        end
      end
    end
    assign r0_o = r[0];
    assign r1_o = r[1];

    assign q0_o  = q[0];
    assign q1_o  = q[1];
    assign lo0_o = d_lo[0];
  end else begin : gen_no_wsr
    assign q0_o  = '0;
    assign q1_o  = '0;
    assign lo0_o = '0;
    assign r0_o  = '0;
    assign r1_o  = '0;
  end
endmodule
