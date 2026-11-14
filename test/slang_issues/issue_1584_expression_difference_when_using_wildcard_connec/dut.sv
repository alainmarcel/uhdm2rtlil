// MikePopoloski/slang#1584 (closed): Expression difference when using wildcard connection vs when not
// https://github.com/MikePopoloski/slang/issues/1584
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module primi(input logic d, output logic q);
endmodule

module top(input logic d, output logic q);
	primi inst(.*);
endmodule

