// YosysHQ/yosys#1193 (closed): SystemVerilog frontend does not implement semantics of always_{ff,comb,latch}
// https://github.com/YosysHQ/yosys/issues/1193
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module test (input e, a, output reg b);
  always_comb
  	if (e)
  		b = a;
endmodule

