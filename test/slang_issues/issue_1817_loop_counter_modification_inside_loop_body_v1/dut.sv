// MikePopoloski/slang#1817 (closed): Loop counter modification inside loop body leads to incorrect iteration count during loop unrolling
// https://github.com/MikePopoloski/slang/issues/1817
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input in);
reg a;
always_latch begin
    if (in)
        for (int i = 0; i < 2; ++i) begin
            i = 2;
            if (i == 2)
                a = 1;
        end
end
endmodule

