// MikePopoloski/slang#1339 (closed): Local variable definite assignment flow
// https://github.com/MikePopoloski/slang/issues/1339
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- c0.sv
sequence s(local int a);
    (1, a++) ##1 1;
endsequence

module m(input clk);
    assert property (@(posedge clk) s(1));
endmodule

