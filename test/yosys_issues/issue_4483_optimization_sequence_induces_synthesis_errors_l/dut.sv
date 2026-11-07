// YosysHQ/yosys#4483 (closed): Optimization Sequence Induces Synthesis Errors Leading to Simulation Inconsistencies
// https://github.com/YosysHQ/yosys/issues/4483
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module top(output logic y);
assign y = 'x;
endmodule

