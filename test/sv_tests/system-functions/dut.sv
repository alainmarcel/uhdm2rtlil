// Converted from chipsalliance/sv-tests (system-functions).
// Upstream's module is a single `$display("hello world")` in an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module systemfn(input logic [31:0] x, output logic [31:0] o);
  // The $display becomes a $print cell, which is the netlist's form of a system task.
  always_comb $display("hello world %d", x);
  assign o = x;
endmodule
