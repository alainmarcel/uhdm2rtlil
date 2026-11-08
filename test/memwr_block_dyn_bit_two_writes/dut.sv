// Two dynamic bit writes to one packed vector in an always @(posedge) block
// that ALSO writes a memory (verilog-pcie pcie_us_axi_dma_wr's op table:
// `op_table_active[start_ptr] <= 1` and `op_table_active[finish_ptr] <= 0`
// beside the op_table_* memory writes).  The memory-write import path had no
// in-flight context, so the second write rebuilt the vector from the
// REGISTERED value and a start + finish in the same cycle lost the start.
module memwr_block_dyn_bit_two_writes (
    input  wire       clk,
    input  wire       rst,
    input  wire       s_en,
    input  wire       f_en,
    input  wire [2:0] sp,
    input  wire [2:0] fp,
    input  wire [3:0] d,
    input  wire [2:0] ra,
    output reg  [7:0] act,
    output wire [3:0] q
);
    reg [3:0] mem [0:7];
    initial act = 0;
    always @(posedge clk) begin
        if (s_en) begin
            act[sp] <= 1'b1;
            mem[sp] <= d;
        end
        if (f_en) act[fp] <= 1'b0;
        if (rst) act <= 0;
    end
    assign q = mem[ra];
endmodule
