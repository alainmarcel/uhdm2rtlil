// povik/sv-elab#76 (closed): Modules with `assert property` fail
// https://github.com/povik/sv-elab/issues/76
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top    
    (
        input logic clk,
        input logic rst,
        input logic in,
        output logic out
    );

always_ff @(posedge clk) out <= in;

dummy_assertion:
    assert property (@(posedge clk) 1'b1);

endmodule

