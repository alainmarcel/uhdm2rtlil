// povik/sv-elab#272 (closed): Assertion naming error
// https://github.com/povik/sv-elab/issues/272
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test (
    input clk,
    rst_n,
    output reg a = 0
);
    always @(posedge clk) begin
        if (!rst_n) begin
            tttt:  assert (a == 0);
            ttt12: assert (a == 0);
        end
    end
endmodule

