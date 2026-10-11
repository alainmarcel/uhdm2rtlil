// A DYNAMIC packed write assigns the WHOLE flat wire (the written bits are no
// static range), so when an unrolled loop puts each iteration in its own
// `switch`, a later switch's assignment DISCARDS the bits an earlier one set:
// with wr == 2'b11 only the last iteration's bit survived.  In an always_ff
// body there is no threaded in-flight value to chain onto (non-blocking reads
// must see the registered value), and chaining unconditionally is wrong too --
// iteration 1 must start from `wr[0] ? v0 : raw`.
module ff_dyn_packed_write_inflight_chain(input logic clk, input logic [1:0] wr, input logic [3:0] ptr_f, output logic [3:0] isStore);
  logic [1:0] ptr [2];
  always_comb for (int i = 0; i < 2; i++) ptr[i] = ptr_f[i*2 +: 2];
  always_ff @(posedge clk) begin
    for (int i = 0; i < 2; i++) begin
      if (wr[i]) begin
        isStore[ ptr[i] ] <= 1'b1;
      end
    end
  end
endmodule
