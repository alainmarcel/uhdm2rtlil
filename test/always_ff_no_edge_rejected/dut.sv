// `always_ff @(clk)` has no edge-sensitive event control, so it does not
// model a flip-flop (LRM 9.2.2.4; MikePopoloski/slang#1660, #1206).
// read_slang and read_verilog reject it; read_uhdm must stop with a clear
// error naming the block, not deep inside the sync-rule builder.
module dut(input logic clk, input logic [7:0] d, output logic [7:0] q);
  always_ff @(clk) q <= d;
endmodule
