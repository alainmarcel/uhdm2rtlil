// povik/sv-elab#296 (open): Regarding handling blackboxes with parameters
// https://github.com/povik/sv-elab/issues/296
// Code block(s) from the issue (variant v2); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
(* blackbox *)
module mymod #(
    parameter int N = 8
) (
    input  logic        clk,
    input  logic        nrst,
    input  logic [N-1:0] a,
    input  logic [N-1:0] b,
    output logic [N-1:0] c
);
endmodule

