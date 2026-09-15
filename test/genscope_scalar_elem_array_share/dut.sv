// Unpacked array of 1-bit elements declared inside an if-generate block,
// driven per element and read per element (acc_alu_bignum gen_pqc_wsr
// `logic kmac_msg_wr_stall [Share]`).
module genscope_scalar_elem_array_share #(
  parameter bit En    = 1'b1,
  parameter int Share = 2
) (
  input  logic [Share-1:0] write_i,
  input  logic [Share-1:0] ready_i,
  input  logic [3:0]       wr_i,
  output logic [3:0]       en0_o,
  output logic [3:0]       en1_o
);
  if (En) begin : gen_wsr
    logic stall [Share];
    logic [3:0] en [Share];
    for (genvar w = 0; w < 4; w++) begin : g_w0
      assign en[0][w] = wr_i[w] & ~stall[0];
    end
    for (genvar w = 0; w < 4; w++) begin : g_w1
      assign en[1][w] = wr_i[w] & ~stall[1];
    end
    assign stall[0] = write_i[0] & ~ready_i[0];
    assign stall[1] = write_i[1] & ~ready_i[1];
    assign en0_o = en[0];
    assign en1_o = en[1];
  end else begin : gen_none
    assign en0_o = '0;
    assign en1_o = '0;
  end
endmodule
