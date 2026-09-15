// A 2-element unpacked array of wide words whose WORD slices are written per
// generate iteration, both in always_comb and always_ff (OpenTitan
// acc_alu_bignum's KMAC message registers:
//   logic [ExtWLEN-1:0] kmac_msg_intg_q [Share];
//   for (genvar i_word ...) begin
//     always_ff ... kmac_msg_intg_q[0][i_word*39+:39] <= kmac_msg_intg_d[0][i_word*39+:39];
//     always_comb   kmac_msg_intg_d[0][i_word*39+:39] = ...;
// read_uhdm aborted with a SigSpec extract assertion in the memory
// partial-write path.
module genloop_share_array_word_slice_writes #(parameter int Words = 4, parameter int W = 8) (
  input  logic                 clk_i,
  input  logic [Words-1:0]     we_i,
  input  logic                 wipe_i,
  input  logic [Words*W-1:0]   rnd_i,
  input  logic [Words*W-1:0]   wdata_i,
  output logic [Words*W-1:0]   q0_o,
  output logic [Words*W-1:0]   q1_o
);
  logic [Words*W-1:0] q [2];
  logic [Words*W-1:0] d [2];
  for (genvar i = 0; i < Words; i++) begin : g_word
    always_ff @(posedge clk_i) begin
      if (we_i[i]) begin
        q[0][i*W+:W] <= d[0][i*W+:W];
        q[1][i*W+:W] <= d[1][i*W+:W];
      end
    end
    always_comb begin
      d[0][i*W+:W] = '0;
      d[1][i*W+:W] = '0;
      if (wipe_i) begin
        d[0][i*W+:W] = rnd_i[i*W+:W];
        d[1][i*W+:W] = ~rnd_i[i*W+:W];
      end else begin
        d[0][i*W+:W] = wdata_i[i*W+:W];
        d[1][i*W+:W] = wdata_i[i*W+:W] ^ rnd_i[i*W+:W];
      end
    end
  end
  assign q0_o = q[0];
  assign q1_o = q[1];
endmodule
