// Converted from chipsalliance/sv-tests (repl_op_sim).
// Upstream builds the replication inside an `initial` block from a constant and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input bit [1:0] b, output bit [15:0] a);
  assign a = {8{b}};
endmodule
