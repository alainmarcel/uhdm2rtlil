// A MEMORY declared inside a `generate` block, written and read at a RUNTIME
// index by an always block in the same scope — the shape every FIFO in
// Alex Forencich's verilog-axis / verilog-pcie / verilog-ethernet uses.
//
// read_uhdm produced an EMPTY MODULE for this.  Three things went wrong, and
// all three had to be fixed:
//
//  1. `collect_proc_elem_written` recorded ANY `arr[...] <= ...` as a
//     "per-element write" regardless of the index, so `fifo[wr_ptr] <= d`
//     forced the array to per-element wires.
//  2. `import_gen_scope`'s Array_nets() loop materialised per-element wires
//     UNCONDITIONALLY — it had no memory-inference branch at all, so a
//     gen-scope array could never become a $mem.  Every element was left
//     undriven: verilog-pcie's dma_ram_demux reported 4096 undriven nets,
//     dma_if_pcie_us 19968, pcie_us_if_rc 12864.
//  3. Once the memory DID appear, the always_ff memory branch dropped the
//     ordinary registers in the same block: it looked their wire up by the
//     BARE name (`wr_ptr`) while in a generate scope the wire is
//     `g[0].wr_ptr`, so no `$0\` temp and no sync rule were created and the
//     register was driven combinationally — `proc` turned it into a mux chain
//     and the FLOP DISAPPEARED.  That gap was pre-existing but unreachable,
//     because a generate scope could never hold a memory before.
//
// The memory is named after the SCOPE (`g[0].fifo_mem`): the generate is
// replicated, so two iterations would otherwise collide on one bare memory.
//
// N = 2 on purpose — a single iteration would not catch the name collision.
// The two iterations store DIFFERENT data (`din + k`) so `opt` cannot merge
// them and hide a missing memory.
module genscope_memory_dyn_index #(parameter N = 2, parameter AW = 3, parameter DW = 8)
(
    input  wire          clk,
    input  wire          rst,
    input  wire [DW-1:0] din,
    input  wire          wr,
    input  wire          rd,
    output wire [DW-1:0] dout
);
genvar k;
generate
for (k = 0; k < N; k = k + 1) begin : g
    reg [AW:0] wr_ptr = 0;
    reg [AW:0] rd_ptr = 0;
    reg [DW-1:0] dout_reg = 0;

    reg [DW-1:0] fifo_mem[2**AW-1:0];

    always @(posedge clk) begin
        if (wr) begin
            fifo_mem[wr_ptr[AW-1:0]] <= din + k[DW-1:0];
            wr_ptr <= wr_ptr + 1;
        end
        if (rd) begin
            dout_reg <= fifo_mem[rd_ptr[AW-1:0]];
            rd_ptr   <= rd_ptr + 1;
        end
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end
    end
end
endgenerate
assign dout = g[0].dout_reg ^ g[N-1].dout_reg;
endmodule
