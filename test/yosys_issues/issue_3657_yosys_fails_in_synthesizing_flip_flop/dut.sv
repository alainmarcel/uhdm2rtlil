// YosysHQ/yosys#3657 (open): yosys fails in synthesizing flip-flop with asynchronous reset and ternary operator ?:
// https://github.com/YosysHQ/yosys/issues/3657
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module ff2 (input logic d, r, ck,
   output logic q);
always_ff @ (posedge ck , posedge r)
 q <= r ? '0 : d;
endmodule

