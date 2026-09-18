// Regression for Caliptra kv_reg (key_vault1 co-sim: every SW register write
// produced load_next=1 with the OLD value): an `automatic` local declared in
// an always_comb that sits inside a generate for-loop.  The reader promoted
// block-locals to ONE bare module wire (`\next_c`), so only iteration 0 was
// consistent: later iterations skipped the promotion, their branch writes
// went to a fresh `gen_f[k].next_c`, the block's init assignment to an
// `$unnamed_block$N.next_c`, and the final `nxt[i] = next_c` read stale.
// Promoted locals now carry the generate-scope prefix.
module dut(input logic clk, input logic rst_n, input logic req, input logic wr, input logic [3:0] data, input logic [3:0] biten, input logic [3:0] hwset,
           output logic [3:0] q, output logic [3:0] nxt_o, output logic [3:0] load_o);
  logic [3:0] storage, nxt, load;
  for (genvar i = 0; i < 4; i++) begin : gen_f
    always_comb begin
      automatic logic [0:0] next_c;
      automatic logic load_next_c;
      next_c = storage[i];
      load_next_c = '0;
      if (req && wr) begin
        next_c = (storage[i] & ~biten[i]) | (data[i] & biten[i]);
        load_next_c = '1;
      end else if (hwset[i]) begin
        next_c = '1;
        load_next_c = '1;
      end
      nxt[i]  = next_c;
      load[i] = load_next_c;
    end
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) storage[i] <= 1'b0;
      else if (load[i]) storage[i] <= nxt[i];
    end
  end
  assign q = storage; assign nxt_o = nxt; assign load_o = load;
endmodule
