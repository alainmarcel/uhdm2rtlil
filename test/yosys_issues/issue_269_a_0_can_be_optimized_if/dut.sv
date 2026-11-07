// YosysHQ/yosys#269 (closed): a < 0 can be optimized if a is signed
// https://github.com/YosysHQ/yosys/issues/269
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module isneg (input signed [7:0] a, output logic o);
   assign o = a < 0;
   //assign o = a[7];
endmodule

