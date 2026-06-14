// === my_pkg.sv ===
package my_pkg;
   parameter int A__B = 1;
endpackage // my_pkg

// === top.sv ===
module top(output int o);
   import my_pkg::*;
   assign o = A__B;
endmodule
