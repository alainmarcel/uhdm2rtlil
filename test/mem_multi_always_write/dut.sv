// Minimal repro: one unpacked array (memory) written from SEVERAL always_ff
// blocks (one per element, via a generate for-loop).  The frontend's
// simple-if-else memory-write path created a fixed-named `$memwr$\mem$addr`
// helper wire per block; the second block re-added the same name and aborted
// Module::add (count_id == 0).  Reduced from ibex_icache, where a generate
// `for (fb)` loop makes NUM_FB always_ff blocks each writing `fill_addr_q[fb]`.
// mem is zero-initialised so RTL and netlist agree on the never-written entries.
module mem_multi_always_write #(parameter int N = 4) (
  input  logic           clk,
  input  logic [N-1:0]   we,
  input  logic [N*8-1:0] d,     // packed: element i is d[i*8 +: 8]
  input  logic [1:0]     radr,
  output logic [7:0]     q
);
  logic [7:0] mem [N];
  initial for (int k = 0; k < N; k++) mem[k] = '0;

  generate
    for (genvar i = 0; i < N; i++) begin : g_wr
      always_ff @(posedge clk)
        if (we[i]) mem[i] <= d[i*8 +: 8];
    end
  endgenerate

  assign q = mem[radr];
endmodule
