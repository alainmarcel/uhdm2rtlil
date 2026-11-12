// povik/sv-elab#269 (closed): BUG: Initial value in output reg declaration ignored
// https://github.com/povik/sv-elab/issues/269
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test (
    input clk,
    rst_n,
    output reg a = 0
);
    always @(posedge clk) begin
        if (!rst_n) begin
            assert (a == 0);
        end
    end
endmodule

