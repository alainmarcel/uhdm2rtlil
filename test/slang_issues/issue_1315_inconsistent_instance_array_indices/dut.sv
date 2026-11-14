// MikePopoloski/slang#1315 (closed): Inconsistent instance array indices
// https://github.com/MikePopoloski/slang/issues/1315
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module subm(input h);
endmodule

module top();
	wire g [1:0];
	subm inst[2:3](.h(g));
endmodule

