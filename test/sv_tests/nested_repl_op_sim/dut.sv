// Converted from chipsalliance/sv-tests (nested_repl_op_sim).
// Upstream builds the nested replication inside an `initial` block from constants and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input bit [1:0] b, input bit [1:0] c, input bit [3:0] d,
           output bit [15:0] a);
  assign a = {{3{b, c}}, d};
endmodule
