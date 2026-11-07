// YosysHQ/yosys#1360 (closed): Instantiating an interface without params fails, BLIF can't find module top
// https://github.com/YosysHQ/yosys/issues/1360
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module top(input clk);
  MyInterface MyInterfaceInstance();
endmodule

interface MyInterface();
  logic not_an_empty_interface;
endinterface

