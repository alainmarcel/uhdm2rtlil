// A clocked LOOP of conditional element writes, followed in the SAME always_ff
// by a CONSTANT-index element override that must win:
//     for (i) if (we_dec[i]) mem[i] <= wdata;
//     mem[0] <= '0;                     // x0 is hardwired to zero
// CVA6 ariane_regfile_ff.sv with ZERO_REG_ZERO=1 — losing the override let
// register 0 read back written data instead of zero.
module dut #(
    parameter int unsigned NUM_WORDS  = 8,
    parameter int unsigned DATA_WIDTH = 8
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic [2:0]              waddr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic                    we,
    input  logic [2:0]              raddr,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    output logic [DATA_WIDTH-1:0]   r0_o
);
  logic [NUM_WORDS-1:0][DATA_WIDTH-1:0] mem;
  logic [NUM_WORDS-1:0]                 we_dec;

  always_comb begin : we_decoder
    for (int unsigned i = 0; i < NUM_WORDS; i++) begin
      if (waddr == i) we_dec[i] = we;
      else we_dec[i] = 1'b0;
    end
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      mem <= '{default: '0};
    end else begin
      for (int unsigned i = 0; i < NUM_WORDS; i++) begin
        if (we_dec[i]) begin
          mem[i] <= wdata;
        end
      end
      //  Must win over the loop write above.
      mem[0] <= '0;
    end
  end

  assign rdata_o = mem[raddr];
  assign r0_o    = mem[0];
endmodule
