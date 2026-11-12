// povik/sv-elab#157 (open): Indeterminate loop unrolling on loops with internal control flow
// https://github.com/povik/sv-elab/issues/157
// Code block(s) from the issue (variant v0); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input x, output reg [2:0] k);
always_comb
begin
    k = 0;
    for (int i = 0; i < 2; i++)
    begin
        k++;
        if (x) begin
            i++; continue;
        end
        break;
    end
end
endmodule

