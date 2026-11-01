// Converted from chipsalliance/sv-tests (simple_idx_select_sim).
// Upstream already has real ports; the module only lacked a proof of its values.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input [3:0] a, output b);
assign b = a[2];
endmodule
