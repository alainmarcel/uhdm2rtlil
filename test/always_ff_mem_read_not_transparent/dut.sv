// A non-blocking read of an array element in the SAME always_ff that writes it
// (`mem[addr] <= (mem[addr] & ~wmask) | (wdata & wmask); rdata <= mem[addr];`)
// must return the REGISTERED word, not the pending write: read_uhdm muxed the
// in-flight element value into the read and built a transparent RAM, so
// HPDcache's hpdcache_regbank_wmask_1rw handed out the word being written one
// cycle early (its cva6 sweep row differed).  Async reset + for-loop clear as
// in the original.
module dut #(parameter int unsigned ADDR_SIZE = 2, parameter int unsigned DATA_SIZE = 4, parameter int unsigned DEPTH = 2**ADDR_SIZE) (
  input logic clk, input logic rst_n, input logic cs, input logic we,
  input logic [ADDR_SIZE-1:0] addr, input logic [DATA_SIZE-1:0] wdata, input logic [DATA_SIZE-1:0] wmask,
  output logic [DATA_SIZE-1:0] rdata);
  typedef logic [DATA_SIZE-1:0] mem_t [DEPTH];
  mem_t mem;
  always_ff @(posedge clk or negedge rst_n) begin : mem_update_ff
    if (!rst_n) begin
      for (int i = 0; i < DEPTH; i++) mem[i] <= '0;
    end else begin
      if (cs == 1'b1) begin
        if (we == 1'b1) mem[addr] <= (mem[addr] & ~wmask) | (wdata & wmask);
        rdata <= mem[addr];
      end
    end
  end
endmodule
