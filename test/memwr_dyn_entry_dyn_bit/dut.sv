// A single BIT of a dynamically indexed memory entry written in an always
// block that also clears the memory in a reset loop (`mem[idx][4+off] <= 0`):
// OpenPiton l15_hmc clears one valid bit of `data_mem_f[wr_index]` that way.
// The sync-path memory-write detection handled a var_select target only for
// memories with two or more unpacked dimensions; on a one-dimensional memory
// the write fell through to a "regular assignment" that imported the target
// as a read, and the bit stayed set (formal `differs`, co-sim PASS).
module dut (input wire clk, input wire rst_n, input wire set_en, input wire clr_en, input wire [1:0] idx, input wire [1:0] off,
            input wire [7:0] wdata, input wire [1:0] ridx, output wire [7:0] rdata);
    reg [7:0] mem [3:0];
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1) mem[i] <= 8'h00;
        end else if (clr_en) begin
            mem[idx][4+off] <= 1'b0;
        end else if (set_en) begin
            mem[idx] <= wdata;
        end
    end
    assign rdata = mem[ridx];
endmodule
