// An element-RANGE select of a packed array-of-vectors declared INSIDE A
// GENERATE SCOPE, used as a child port actual: `.operands_i(local_operands[1:0])`
// (fpnew_opgroup_multifmt_slice hands its 2 of 3 lane operands to the
// divsqrt unit this way).  The variable carries its ranges on its typespec,
// not on itself, so the generate-scope geometry stamp never ran and the
// select was imported as a 2-BIT slice.  The module-level twin was right.
module child #(parameter int unsigned W = 8)
  (input logic [1:0][W-1:0] operands_i, output logic [W-1:0] q);
  assign q = operands_i[0] ^ operands_i[1];
endmodule
module dut(input logic [2:0][63:0] a, output logic [63:0] q_top, output logic [63:0] q_gen, output logic [63:0] q_gen8);
  localparam int unsigned NUM_OPERANDS = 3;
  // module level: a 3-operand packed array, the child takes elements [1:0]
  logic [NUM_OPERANDS-1:0][63:0] lt;
  always_comb for (int unsigned i = 0; i < NUM_OPERANDS; i++) lt[i] = a[i];
  child #(.W(64)) c_top (.operands_i(lt[1:0]), .q(q_top));
  // generate scope: same, with the element width from a gen-scope localparam
  for (genvar lane = 0; lane < 1; lane++) begin : g
    localparam int unsigned LANE_WIDTH = 64;
    if (1) begin : active_lane
      logic [NUM_OPERANDS-1:0][LANE_WIDTH-1:0] local_operands;
      always_comb for (int unsigned i = 0; i < NUM_OPERANDS; i++) local_operands[i] = a[i];
      child #(.W(LANE_WIDTH)) c_gen (.operands_i(local_operands[1:0]), .q(q_gen));
    end
  end
  for (genvar lane = 1; lane < 2; lane++) begin : h
    localparam int unsigned LANE_WIDTH = 8;
    if (1) begin : active_lane
      logic [NUM_OPERANDS-1:0][LANE_WIDTH-1:0] local_operands;
      always_comb for (int unsigned i = 0; i < NUM_OPERANDS; i++) local_operands[i] = a[i] >> 8;
      child #(.W(LANE_WIDTH)) c_gen (.operands_i(local_operands[1:0]), .q(q_gen8[7:0]));
      assign q_gen8[63:8] = '0;
    end
  end
endmodule
