// povik/sv-elab#324 (open): SVA `assert property` cannot read an inferred memory
// https://github.com/povik/sv-elab/issues/324
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (
    input logic clk,
    input logic rst_n,
    input logic [3:0] idx,
    input logic [7:0] expected
);
    logic [7:0] mem [0:15];

`ifdef USE_P1
    P1: assert property (@(posedge clk) disable iff (!rst_n) mem[idx] == expected);
`else
    always @(posedge clk) begin
        if (rst_n) begin
            P0: assert (mem[idx] == expected);
        end
    end
`endif
endmodule

