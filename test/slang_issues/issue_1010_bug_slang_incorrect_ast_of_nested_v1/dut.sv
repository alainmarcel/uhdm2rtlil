// MikePopoloski/slang#1010 (closed): [bug][slang] Incorrect AST of nested submodule
// https://github.com/MikePopoloski/slang/issues/1010
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module test();
    module test1(input clk);
        function void foo();
        endfunction
    endmodule
endmodule

