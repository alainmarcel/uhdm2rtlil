// YosysHQ/yosys#3819 (open): Improve detection of multiply declared signals in SV frontend
// https://github.com/YosysHQ/yosys/issues/3819
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): output added that reads the doubly declared `bar`

// ---- b0.sv
module foo(input wire bar, output wire o);
assign o = bar;

logic bar; //should warn but does not currently

endmodule

