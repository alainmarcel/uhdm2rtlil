// YosysHQ/yosys#1053: SystemVerilog interface fields are implicitly defined?
// https://github.com/YosysHQ/yosys/issues/1053
// A hierarchical read of an interface instance's members from the module that instantiates it (assign o = MyInterfaceInstance.mysig_out).  Under `default_nettype none` Surelog itself reports a false EL0535 'Illegal implicit net' for that reference (the UHDM is still right), so this test reads without the directive.

interface MyInterface;
  logic mysig_out;
  logic [3:0] setting;
endinterface
module SubModule(MyInterface i, input logic clk, input logic [3:0] d);
  always_ff @(posedge clk) i.setting <= d;
  assign i.mysig_out = ^i.setting;
endmodule
module dut(input logic clk, input logic [3:0] d, output logic o, output logic [3:0] s);
  MyInterface MyInterfaceInstance();
  SubModule u(.i(MyInterfaceInstance), .clk(clk), .d(d));
  assign o = MyInterfaceInstance.mysig_out;
  assign s = MyInterfaceInstance.setting;
endmodule
