// MikePopoloski/slang#1411 (closed): Invalid expression nodes with `--ignore-unknown-modules`
// https://github.com/MikePopoloski/slang/issues/1411
// Code block(s) from the issue (variant s1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(input clk);
    always @(posedge clk) begin
        $fatal("foo");
    end
endmodule

