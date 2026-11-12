// povik/sv-elab#230 (closed): weird assignement to int error
// https://github.com/povik/sv-elab/issues/230
// Code block(s) from the issue (variant h0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module test (output int out_sum);
    logic [3:0] val = 4'd5;
    always_comb begin
        out_sum = val;
    end
endmodule

