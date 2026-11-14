// MikePopoloski/slang#1895 (closed): Output port variable initializer is not treated as a driver
// https://github.com/MikePopoloski/slang/issues/1895
// Code block(s) from the issue (variant v0); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top(output reg r=0);
assign r = 1;
endmodule

