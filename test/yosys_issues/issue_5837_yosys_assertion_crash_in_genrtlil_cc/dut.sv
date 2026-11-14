// YosysHQ/yosys#5837 (open): yosys: assertion crash in genrtlil.cc with ascending packed bit range in memory array
// https://github.com/YosysHQ/yosys/issues/5837
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(output logic out,
  input logic [1:0] __i_addr);
  bit [1:2] v1 [1:1];
  logic [1:0] addr;
  always_comb begin
    for (int i = 1; i <= 1; i++)
      if (v1[addr + 1][i]) out = 1'b1;
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign addr = __i_addr;
endmodule

