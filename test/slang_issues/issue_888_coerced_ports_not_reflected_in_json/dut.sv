// MikePopoloski/slang#888 (closed): Coerced ports not reflected in JSON output
// https://github.com/MikePopoloski/slang/issues/888
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module foo(input a);

assign a = 1;

endmodule

