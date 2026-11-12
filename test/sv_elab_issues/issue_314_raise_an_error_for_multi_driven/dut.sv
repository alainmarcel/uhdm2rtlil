// povik/sv-elab#314 (open): Raise an error for multi-driven variables and uwire
// https://github.com/povik/sv-elab/issues/314
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (
    input  logic a,
    input  logic b,
    output logic c
);

    assign c = a;
    assign c = b;

endmodule

