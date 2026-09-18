// Regression for the 1599 undriven nets under the Caliptra chip's
// abr_inst.sampler_top_inst.sha3_inst.u_keccak unmasked rounds.
//
// `storage_datapath` has TWO unpacked dimensions; it materialises as one wire
// per OUTER index, each holding (inner dims x element) bits.  The second index
// of `storage_datapath[0][0]` therefore selects an inner ROW, not a bit — read
// as a bit select the row assign drove ONE bit and every keccak stage's `s_i`
// row went undriven.
module stage #(parameter int Width = 16, parameter int Share = 1) (
  input  logic             clk,
  input  logic [7:0]       rnd,
  input  logic [Width-1:0] s_i [Share],
  output logic [Width-1:0] s_o [Share]
);
  for (genvar i = 0; i < Share; i++) begin : g
    assign s_o[i] = {s_i[i][Width-2:0], s_i[i][Width-1]} ^ {Width{rnd[i]}};
  end
endmodule

module dut #(parameter int Width = 16, parameter int RoundsPerClock = 3) (
  input  logic             clk,
  input  logic [7:0]       round,
  input  logic [Width-1:0] storage [1],
  output logic [Width-1:0] out_o
);
  logic [Width-1:0] storage_datapath [RoundsPerClock:0][0:0];

  assign storage_datapath[0][0] = storage[0];

  for (genvar inst_g = 0; inst_g < RoundsPerClock; inst_g++) begin : round_gen
    stage #(.Width(Width), .Share(1)) u_p (
      .clk,
      .rnd (8'(round + inst_g)),
      .s_i (storage_datapath[inst_g]),
      .s_o (storage_datapath[inst_g + 1])
    );
  end

  assign out_o = storage_datapath[RoundsPerClock][0];
endmodule
