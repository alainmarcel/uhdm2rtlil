// YosysHQ/yosys#3223 (open): Move SVA code out of Verific driver into core?
// https://github.com/YosysHQ/yosys/issues/3223
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module very_simple(input clk, input data);
    assert property( @(posedge clk) data |=> ~data);
endmodule

