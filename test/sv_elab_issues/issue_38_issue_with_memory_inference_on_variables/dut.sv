// povik/sv-elab#38 (closed): Issue with memory inference on variables with async reset
// https://github.com/povik/sv-elab/issues/38
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module multiport_mem #(
    parameter integer NUM_COUNTERS = 2,
    localparam integer NUM_COUNTERS_BITS = NUM_COUNTERS == 1 ? 0 : $clog2(NUM_COUNTERS)-1
) (
    input logic clk_i,
    input logic rstn_i,
    input logic [NUM_COUNTERS_BITS:0] sel_i,
    input logic sync_rst_i,
    output logic [5:0] count
);
    logic [5:0] counter [NUM_COUNTERS-1:0];

    assign count =  counter [sel_i];

    always_ff @( posedge clk_i or negedge rstn_i ) begin : blockName
        if (~rstn_i) begin
            for (integer i =0; i < NUM_COUNTERS; i++) begin
                counter[i] <= 6'd0;
            end
        end else if (sync_rst_i) begin
            counter[sel_i] <= 6'd0;
        end else begin
            for (integer i =0; i < NUM_COUNTERS; i++) begin
                if (counter[i] != 6'd0) begin
                    counter[i]   <= counter[i] - 6'd1;
                end
            end
        end
    end
endmodule

