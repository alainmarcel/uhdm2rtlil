// YosysHQ/yosys#1592: a clock passed as an interface PORT (`interface dummybus
// (input clk, input rst)`) and used through a modport (`bus.clk`) was
// mis-synthesised away by read_verilog.  The counter in `device` must advance.
interface dummybus (input clk, input rst);
  modport device(input clk, input rst);
endinterface
module device (dummybus.device bus, output logic [7:0] keep);
  always @(posedge bus.clk)
    if (bus.rst) keep <= '0;
    else keep <= keep + 1'b1;
endmodule
module dut (input clk, input rst, output logic [7:0] keep);
  dummybus bus (.clk(clk), .rst(rst));
  device dev (.bus(bus), .keep(keep));
endmodule
