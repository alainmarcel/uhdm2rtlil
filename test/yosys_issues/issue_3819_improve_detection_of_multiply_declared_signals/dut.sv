// YosysHQ/yosys#3819 (open): Improve detection of multiply declared signals in SV frontend
// https://github.com/YosysHQ/yosys/issues/3819
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module foo(input wire bar);

logic bar; //should warn but does not currently

endmodule

