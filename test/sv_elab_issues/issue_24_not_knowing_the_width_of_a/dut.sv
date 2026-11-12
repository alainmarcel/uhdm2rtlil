// povik/sv-elab#24 (closed): Not knowing the width of a wire doesn't end up in an error
// https://github.com/povik/sv-elab/issues/24
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module t01(in0);
    input logic [WIDTH-1:0] in0;
endmodule

