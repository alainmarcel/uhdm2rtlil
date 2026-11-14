// MikePopoloski/slang#1385 (closed): [bug][slang-netlist] Combination loops on different bits of the same variable
// https://github.com/MikePopoloski/slang/issues/1385
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m();

wire [10:0]w;

  assign w[0] = w[3];

endmodule

