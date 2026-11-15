// A 2-state unpacked array that is never assigned reads 0 (LRM 6.8: the
// default initial value of `bit` / `byte` is 0).  read_uhdm left its element
// wires undriven, so a read was X (yosys#5837: `if (v1[addr+1][i])` folded the
// latch it guards to 1; read_slang initialises the array to 0).  Each read is
// XORed with an input, so a correct netlist passes the input straight through.
module dut(input logic [1:0] addr, input logic [1:0] d, input logic [7:0] e,
           output logic [1:0] y, output logic [7:0] z);
  bit  [1:0] v [0:3];
  byte       b [0:1];
  assign y = d ^ v[addr];
  assign z = e ^ b[addr[0]];
endmodule
