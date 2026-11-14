// MikePopoloski/slang#995 (closed): [Struct]When translating stuct expression and the memberaccess kind, member symbol is the same while clang will give the different symbol.
// https://github.com/MikePopoloski/slang/issues/995
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module Foo;
  int x, y;
  always_comb begin
    typedef struct packed signed {int a, b;} int64;
    int64 ii;
    int64 bb;
    ii.b = x;
    bb.b = x;
  end
endmodule

