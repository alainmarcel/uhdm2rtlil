// povik/sv-elab#249 (closed): Initializers ignored
// https://github.com/povik/sv-elab/issues/249
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (
    input logic [3:0] in_a,
    input logic [3:0] in_b,
    input logic sel1,
    input logic sel2,
    output logic [3:0] out_y
);
    logic [3:0] inc_a = in_a + 4'd1;
    logic [3:0] dec_b = in_b - 4'd1;

    assign out_y = sel1 ? (sel2 ? in_a : in_b)
                        : (sel2 ? inc_a : dec_b);
endmodule

