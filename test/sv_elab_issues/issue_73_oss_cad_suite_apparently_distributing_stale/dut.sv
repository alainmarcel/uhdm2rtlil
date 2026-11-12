// povik/sv-elab#73 (closed): OSS CAD suite apparently distributing stale (broken) build
// https://github.com/povik/sv-elab/issues/73
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module fifo (
    input logic clk,
    input logic rst,
    input logic [7:0] wrdata_i,
    input logic wr_i,
    output logic [7:0] rddata_o,
    input logic rd_i
);

    logic [127:0] s_mem_flat; // DEPTH=16, WIDTH=8
    logic [3:0] s_wr_ptr, s_rd_ptr; // PTR_WIDTH=4

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            s_mem_flat <= '0;
        end else if (wr_i) begin
            s_mem_flat[(s_wr_ptr * 8) +: 8] <= wrdata_i;
        end
    end

    always_ff @(posedge clk) begin
        if (rd_i) begin
            rddata_o <= s_mem_flat[(s_rd_ptr * 8) +: 8];
        end
    end
endmodule

