// A DOWN-COUNTING for loop whose body is a GUARDED shift between elements of
// the same unpacked array — the output-pipeline shape every FIFO in Alex
// Forencich's verilog-axis / verilog-pcie / verilog-ethernet uses:
//
//     for (j = RAM_PIPELINE; j > 0; j = j - 1)
//         if (ready) m_axis_pipe_reg[j] <= m_axis_pipe_reg[j-1];
//
// read_uhdm dropped the shift write entirely: the $mem came out with ONE write
// port instead of two, so the pipeline never advanced.  Nine separate layers
// had to be fixed in the sync for-loop unroller, in this order:
//
//  1. the init parser required a LITERAL, so `j = RAM_PIPELINE+1-1` (an
//     operation) left can_unroll false;
//  2. the condition parser accepted only `<`, `<=`, `!=` — every DESCENDING
//     loop bailed out with "Cannot unroll for loop - complex pattern" and its
//     body was silently dropped;
//  3. the increment parser accepted only `i = i + N`, not `i = i - N`;
//  4. the iteration compared ascending regardless of the increment's sign;
//  5. an if/if-else body went to `interpret_statement`, a CONSTANT interpreter
//     that can only write scalar variables back, so a guarded memory write
//     produced nothing while still logging success;
//  6. the unrolled write's LHS was imported as an EXPRESSION, i.e. a `$memrd`,
//     so the assignment became `memrd_DATA_1 <= memrd_DATA_2` — a write into a
//     read-data wire, which `opt` deletes;
//  7. the collected writes were drained by a block that lived INSIDE the
//     vpiBegin body branch, so an if-body collected writes nothing emitted;
//  8. that drain hard-coded 10-bit ADDR and 4-bit DATA/EN ("for this test"),
//     which is wrong for any other memory geometry;
//  9. it drove those control wires from the SYNC rule, registering them, so
//     the address arrived a cycle late.
//
// N = 2 elements with DIFFERENT data per stage so `opt` cannot merge them.
module forloop_desc_array_shift #(parameter PIPE = 1, parameter W = 8)
(
    input  wire         clk,
    input  wire         en,
    input  wire         ld,
    input  wire [W-1:0] din,
    output wire [W-1:0] dout
);
reg [W-1:0] p_reg[PIPE+1-1:0];
integer j;
always @(posedge clk) begin
    for (j = PIPE+1-1; j > 0; j = j - 1) begin
        if (en) begin
            p_reg[j] <= p_reg[j-1];
        end
    end
    if (ld) begin
        p_reg[0] <= din;
    end
end
assign dout = p_reg[PIPE+1-1];
endmodule
