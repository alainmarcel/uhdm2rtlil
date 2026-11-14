// MikePopoloski/slang#1817 (closed): Loop counter modification inside loop body leads to incorrect iteration count during loop unrolling
// https://github.com/MikePopoloski/slang/issues/1817
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top();
reg a;
always_latch begin
    for (int i = 0; i < 2; ++i) begin
        i = 100;
        if (i == 1)
            a = 1;
    end
end
endmodule

