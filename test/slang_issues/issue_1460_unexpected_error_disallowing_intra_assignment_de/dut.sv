// MikePopoloski/slang#1460 (closed): Unexpected error disallowing intra-assignment delay in always_comb block.
// https://github.com/MikePopoloski/slang/issues/1460
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module M;
logic a,b;

always_comb
    a <= #1ns b;

endmodule

