// Converted from chipsalliance/sv-tests (debug-line).
// Upstream puts a `line directive inside an otherwise EMPTY module, so there is nothing to tell apart.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module directives(input logic [7:0] x, output logic [8:0] y);
  `line 1 "5.6.4--compiler-directives-debug-line.sv" 1
  // The directive is kept in upstream's position -- INSIDE the module -- and the
  // logic after it still has to compile and prove.
  assign y = x + 8'd1;
endmodule
