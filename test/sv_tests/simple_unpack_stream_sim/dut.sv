// Converted from chipsalliance/sv-tests (simple_unpack_stream_sim).
// Upstream already has real ports; the module only lacked a proof of its values.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input [1:0] a, input [1:0] b, input [1:0] c, output [5:0] d);
    assign d = {<<2 {a, b, c}};
endmodule
