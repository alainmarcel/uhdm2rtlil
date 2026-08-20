// CVA6 behavioural byte-enable SRAM: a MEMORY whose element is a packed 2-D
// array, written per byte under two nested loop variables.
//     typedef logic [NDATA-1:0][DATA_SIZE-1:0] mem_t [DEPTH];
//     for (int j...) for (int i...)
//        if (wbyteenable[j][i]) mem[addr][j][i*8 +: 8] <= wdata[j][i*8 +: 8];
module dut #(
    parameter int unsigned DATA_SIZE = 64,
    parameter int unsigned DEPTH     = 4,
    parameter int unsigned NDATA     = 2
) (
    input  logic                              clk,
    input  logic                              cs,
    input  logic                              we,
    input  logic [1:0]                        addr,
    input  logic [NDATA-1:0][DATA_SIZE-1:0]   wdata,
    input  logic [NDATA-1:0][DATA_SIZE/8-1:0] wbyteenable,
    output logic [NDATA-1:0][DATA_SIZE-1:0]   rdata
);
  typedef logic [NDATA-1:0][DATA_SIZE-1:0] mem_t [DEPTH];
  mem_t mem;

  always_ff @(posedge clk) begin
    if (cs) begin
      if (we) begin
        for (int j = 0; j < NDATA; j++) begin
          for (int i = 0; i < DATA_SIZE/8; i++) begin
            if (wbyteenable[j][i]) mem[addr][j][i*8 +: 8] <= wdata[j][i*8 +: 8];
          end
        end
      end
      rdata <= mem[addr];
    end
  end
endmodule
