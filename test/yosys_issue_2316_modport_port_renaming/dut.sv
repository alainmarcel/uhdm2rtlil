// YosysHQ/yosys#2316: Handle SystemVerilog modport port renaming
// https://github.com/YosysHQ/yosys/issues/2316
// A modport expression (`output .Dout(dinit)`, LRM 25.5.4) names the port one
// way inside the module and connects it to another member of the instance.
// Both the whole-instance actual (`.p(bus)`) and the modport-qualified one
// (`.p(bus2.Initiator)`) are exercised.
interface bus_if;
  logic clk, address, dinit, dtarget, ready;
  modport Initiator(input clk, output address, output .Dout(dinit), input .Din(dtarget), input ready);
  modport Target(input clk, input address, input .Din(dinit), output .Dout(dtarget), output ready);
endinterface
module init(bus_if.Initiator p, input logic a);
  assign p.Dout = a;
  assign p.address = p.Din ^ a;
endmodule
module targ(bus_if.Target p, input logic b);
  assign p.Dout = p.Din & b;
  assign p.ready = p.address;
endmodule
module dut(input logic clk, a, b, c, d, output logic ready, dinit, dtarget, ready2, dinit2, dtarget2);
  bus_if bus();
  assign bus.clk = clk;
  init u0(.p(bus), .a(a));
  targ u1(.p(bus), .b(b));
  assign ready = bus.ready; assign dinit = bus.dinit; assign dtarget = bus.dtarget;
  bus_if bus2();
  assign bus2.clk = clk;
  init u2(.p(bus2.Initiator), .a(c));
  targ u3(.p(bus2.Target), .b(d));
  assign ready2 = bus2.ready; assign dinit2 = bus2.dinit; assign dtarget2 = bus2.dtarget;
endmodule
