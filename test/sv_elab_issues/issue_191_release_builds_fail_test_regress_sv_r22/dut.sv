// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r22); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r22
// propagate bounds through multiplication
module r22(input clk, input [31:0] i, output reg [31:0] q,
           input [1:0] a, input [1:0] b);
    always @(posedge clk) begin
        q = i;
        for (int i = 1; i < a * b; i++)
            q = q * i;
    end
endmodule

