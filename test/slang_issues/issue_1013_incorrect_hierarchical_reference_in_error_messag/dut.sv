// MikePopoloski/slang#1013 (closed): Incorrect hierarchical reference in error message
// https://github.com/MikePopoloski/slang/issues/1013
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t40;
typedef struct {
        logic a;
        logic b;
} t;
t x, y, z;
assign z = x & y;

endmodule

