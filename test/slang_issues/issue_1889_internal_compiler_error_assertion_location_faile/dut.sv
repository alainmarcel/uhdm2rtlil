// MikePopoloski/slang#1889 (closed): internal compiler error: Assertion 'location' failed in Diagnostics.cpp, line 136
// https://github.com/MikePopoloski/slang/issues/1889
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t;

  function int unsigned foo(input int unsigned n);
    foo = 1;
    while (n != 0) begin
      n = n + 1;
    end
  endfunction

  initial begin
    while (foo(1) != 1) begin end
  end
endmodule

