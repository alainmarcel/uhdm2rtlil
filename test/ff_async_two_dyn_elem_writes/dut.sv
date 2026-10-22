// Two DYNAMIC element writes to one packed array in sibling `if`s of an
// ASYNC-RESET always_ff (OpenTitan rram_phy_rd_buf_dep's per-buffer
// dependency counters: one buffer incremented, another decremented, in the
// same cycle).  Each write is a read-modify-write of the whole flat wire,
// so the second must start from the value the FIRST staged -- the sync-only
// always_ff path reconstructs that from the process's switches, but the
// async-reset path imported its clocked arm with no fold root at all, so the
// second write chained onto the REGISTERED value and discarded the first:
// with both enables up on different elements only element ib changed.
module dut (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       we_a,
  input  logic       we_b,
  input  logic [1:0] ia,
  input  logic [1:0] ib,
  input  logic [1:0] da,
  input  logic [1:0] db,
  output logic [3:0][1:0] cnt
);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= '0;
    end else begin
      if (we_a) cnt[ia] <= da;
      if (we_b) cnt[ib] <= db;
    end
  end
endmodule
