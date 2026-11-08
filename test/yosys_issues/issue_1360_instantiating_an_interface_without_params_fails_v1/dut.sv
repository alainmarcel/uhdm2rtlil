// YosysHQ/yosys#1360 (closed): Instantiating an interface without params fails, BLIF can't find module top
// https://github.com/YosysHQ/yosys/issues/1360
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): top drives an output THROUGH the interface member, so the instance is not an empty module

// ---- b0.sv
module top(input clk, output o);
  assign MyInterfaceInstance.not_an_empty_interface = clk;
  assign o = MyInterfaceInstance.not_an_empty_interface;
  MyInterface MyInterfaceInstance();
endmodule

interface MyInterface();
  logic not_an_empty_interface;
endinterface

