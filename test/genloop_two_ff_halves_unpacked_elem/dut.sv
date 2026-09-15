// Two always_ff blocks per generate iteration writing the LOWER and UPPER
// halves of the same unpacked-array element (OpenTitan acc_rf_bignum_ff, the
// flip-flop bignum register file the Egret top selects:
//   rf[i][0+:ExtWLEN/2]         <= wr_data_blanked[0+:ExtWLEN/2];
//   rf[i][ExtWLEN/2+:ExtWLEN/2] <= wr_data_blanked[ExtWLEN/2+:ExtWLEN/2];).
// read_uhdm made each process drive the whole element: 9984 conflicting
// drivers in the Egret acc_core register file.
module genloop_two_ff_halves_unpacked_elem_mux #(parameter int N = 4, parameter int W = 8) (
  input  logic [W-1:0] in_i [N],
  input  logic [N-1:0] sel_i,
  output logic [W-1:0] out_o
);
  always_comb begin
    out_o = '0;
    for (int k = 0; k < N; k++) out_o |= in_i[k] & {W{sel_i[k]}};
  end
endmodule

module genloop_two_ff_halves_unpacked_elem #(parameter int N = 4, parameter int W = 8) (
  input  logic                 clk_i,
  input  logic [$clog2(N)-1:0] wr_addr_i,
  input  logic [1:0]           wr_en_i,
  input  logic [W-1:0]         wr_data_i,
  input  logic [N-1:0]         rd_sel_i,
  output logic [W-1:0]         rd_data_o
);
  logic [W-1:0] rf [N];
  for (genvar i = 0; i < N; i++) begin : g_rf
    logic [1:0] we;
    assign we = wr_en_i & {2{wr_addr_i == i}};
    always_ff @(posedge clk_i) begin
      if (we[0]) begin
        rf[i][0+:W/2] <= wr_data_i[0+:W/2];
      end
    end
    always_ff @(posedge clk_i) begin
      if (we[1]) begin
        rf[i][W/2+:W/2] <= wr_data_i[W/2+:W/2];
      end
    end
  end
  // The whole array goes to a child through an unpacked-array port (as
  // acc_rf_bignum_ff feeds prim_onehot_mux), so it is not a memory.
  genloop_two_ff_halves_unpacked_elem_mux #(.N(N), .W(W)) u_mux (
    .in_i(rf), .sel_i(rd_sel_i), .out_o(rd_data_o)
  );
endmodule
