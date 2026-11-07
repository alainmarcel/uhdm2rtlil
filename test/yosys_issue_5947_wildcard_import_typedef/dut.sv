// YosysHQ/yosys#5947: `import test_pkg::*;` before the module did not make the
// package's typedef (byte_t) or parameter (XLEN) visible to the port list in
// read_verilog -sv.  Both names must resolve: x is 32 bits, a and b are 8.
package test_pkg;
  localparam int XLEN = 32;
  typedef logic [7:0] byte_t;
endpackage
import test_pkg::*;
module dut (
  input  logic [XLEN-1:0] x,
  input  byte_t a,
  output byte_t b,
  output logic [XLEN-1:0] y
);
  byte_t c;
  assign c = a;
  assign b = c;
  assign y = x;
endmodule
