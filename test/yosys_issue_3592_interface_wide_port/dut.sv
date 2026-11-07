// YosysHQ/yosys#3592: an 8-bit interface signal read through a modport
// (`bus.a` on `inf.Slave bus`) was treated as a single bit by read_verilog.
// Wrapped so the top has plain ports: r must capture all 8 bits of a.
interface inf;
  logic [7:0] a;
  modport Slave(input a);
endinterface
module sink (input clk, inf.Slave bus, output logic [7:0] r);
  always_ff @(posedge clk) r <= bus.a;
endmodule
module dut (input clk, input [7:0] a, output logic [7:0] r);
  inf bus();
  assign bus.a = a;
  sink s (.clk(clk), .bus(bus), .r(r));
endmodule
