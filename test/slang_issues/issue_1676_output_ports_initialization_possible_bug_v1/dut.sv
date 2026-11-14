// MikePopoloski/slang#1676 (closed): Output ports initialization possible bug
// https://github.com/MikePopoloski/slang/issues/1676
// Code block(s) from the issue (variant v1); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(output reg p = 1'b0);
endmodule

