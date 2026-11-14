// MikePopoloski/slang#1853 (closed): Clarification: input logic w treated as variable (not net) - apparent conflict with 23.2.2.3 first-port rule
// https://github.com/MikePopoloski/slang/issues/1853
// Code block(s) from the issue (variant v2); harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(input bit w);
endmodule

