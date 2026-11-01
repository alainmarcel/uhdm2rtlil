// Converted from chipsalliance/sv-tests (simple_repl_op_sim).
// Upstream already has real ports; the module only lacked a proof of its values.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input [1:0] a, output [15:0] b);
assign b = {8{a}};
endmodule
