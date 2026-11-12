// povik/sv-elab#157 (open): Indeterminate loop unrolling on loops with internal control flow
// https://github.com/povik/sv-elab/issues/157
// Code block(s) from the issue (variant v1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(input x, output reg [2:0] k);
always_comb
begin
    int i;
    k = 0; i = 0;
    while (i < 2)
    begin
        if (x) break;
        i++;
        k++;
    end
end
endmodule

