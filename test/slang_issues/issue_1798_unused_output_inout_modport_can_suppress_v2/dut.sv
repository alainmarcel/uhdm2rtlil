// MikePopoloski/slang#1798 (closed): Unused output / inout modport can suppress `-Wundriven-net` on interface signals
// https://github.com/MikePopoloski/slang/issues/1798
// Code block(s) from the issue (variant v2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m #(parameter p = 0)(output o);
    if (p) assign o = 1;
endmodule

