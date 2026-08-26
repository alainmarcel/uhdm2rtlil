// Byte-enable register bank with an asynchronous reset that clears the whole
// unpacked memory array (hpdcache_regbank_wbyteenable_1rw pattern).
module dut #(
    parameter int unsigned DATA_SIZE = 32,
    parameter int unsigned ADDR_SIZE = 1,
    parameter int unsigned DEPTH     = 1
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     cs,
    input  logic                     we,
    input  logic [ADDR_SIZE-1:0]     addr,
    input  logic [DATA_SIZE/8-1:0]   wbyteenable,
    input  logic [DATA_SIZE-1:0]     wdata,
    output logic [DATA_SIZE-1:0]     rdata
);
    typedef logic [DATA_SIZE-1:0] mem_t [DEPTH];
    mem_t mem;

    always_ff @(posedge clk or negedge rst_n) begin : mem_update_ff
        if (!rst_n) begin
            for (int unsigned i = 0; i < DEPTH; i++) begin
                mem[i] <= '0;
            end
        end else begin
            if (cs) begin
                if (we) begin
                    for (int unsigned i = 0; i < DATA_SIZE/8; i++) begin
                        if (wbyteenable[i]) mem[addr][i*8 +: 8] <= wdata[i*8 +: 8];
                    end
                end
                rdata <= mem[addr];
            end
        end
    end
endmodule
