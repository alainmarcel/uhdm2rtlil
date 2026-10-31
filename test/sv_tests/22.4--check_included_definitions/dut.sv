// Converted from chipsalliance/sv-tests (22.4--check_included_definitions, :type: preprocessing).
// Upstream checks both included macros with $display(":assert:" ...), which synthesis cannot see.
// The included file DEFINES two macros, so unlike the rest of the 22.4 group
// this test does not have to settle for "it compiled": both macros drive real
// outputs, so the include taking effect is directly observable.
// Upstream kept as orig.sv; its payload is vendored at the path the directive
// names, so the test is self-contained.
`include "include_directory/defs.sv"
module top(input logic [7:0] a, output logic [8:0] y, output logic str_ok);
  assign y      = a + `TWO_PLUS_TWO;                // `TWO_PLUS_TWO is 5
  assign str_ok = (`define_var == "define_var");     // `define_var is that string
endmodule
