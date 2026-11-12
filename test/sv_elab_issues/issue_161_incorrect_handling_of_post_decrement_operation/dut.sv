// povik/sv-elab#161 (closed): Incorrect handling of post-decrement operation in `always_comb`
// https://github.com/povik/sv-elab/issues/161
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module expr_postsub_comb (
    input logic [7:0] in_val_m2,
    input logic [7:0] sub_val_m2,
    output logic [7:0] out_diff_m2,
    output logic [7:0] var_out_m2
);
    logic [7:0] var_m2;
    always_comb begin
        var_m2 = in_val_m2;
        out_diff_m2 = (var_m2--) - sub_val_m2;
        var_out_m2 = var_m2;
    end
endmodule

