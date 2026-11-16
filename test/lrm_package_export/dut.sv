// IEEE 1800-2023 26.6: package export.  A package that imports a name and
// EXPORTS it makes the name importable through itself.
package base_pkg;
  typedef logic [3:0] nib_t;
  localparam nib_t K = 4'd9;
  function automatic nib_t inc(nib_t x); return x + 4'd1; endfunction
endpackage

package top_pkg;
  import base_pkg::*;
  export base_pkg::nib_t;
  export base_pkg::K;
  export base_pkg::inc;
  localparam nib_t K2 = K + 4'd1;
endpackage

module dut import top_pkg::*; (input nib_t a, output nib_t y, z);
  assign y = inc(a) ^ K;
  assign z = a + K2;
endmodule
