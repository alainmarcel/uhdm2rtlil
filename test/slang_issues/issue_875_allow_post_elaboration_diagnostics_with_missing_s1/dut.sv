// MikePopoloski/slang#875 (closed): Allow post-elaboration diagnostics with missing modules
// https://github.com/MikePopoloski/slang/issues/875
// Code block(s) from the issue (variant s1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module n;
    assign m.foo = 1;
endmodule

