// aes_prng_clearing (Width=64, NumSharesKey=2 output shares).
// Multi-element unpacked-array ports flattened elem0@LSB (read_uhdm and read_slang
// flatten unpacked ports in opposite element order, so the miter/co-sim compare
// through this wrapper — same convention as the KMAC/EDN masked wrappers).
module aes_prng_clearing_flat import aes_pkg::*; (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic data_req_i,
  output logic data_ack_o,
  output logic [127:0] data_o_flat,
  input  logic reseed_req_i,
  output logic reseed_ack_o,
  output logic entropy_req_o,
  input  logic entropy_ack_i,
  input  logic [edn_pkg::ENDPOINT_BUS_WIDTH-1:0] entropy_i
);
  logic [63:0] data_o [2];
  assign data_o_flat[63:0] = data_o[0];
  assign data_o_flat[127:64] = data_o[1];
  aes_prng_clearing u (
    .clk_i, .rst_ni, .data_req_i, .data_ack_o, .data_o(data_o), .reseed_req_i, .reseed_ack_o, .entropy_req_o, .entropy_ack_i, .entropy_i
  );
endmodule
