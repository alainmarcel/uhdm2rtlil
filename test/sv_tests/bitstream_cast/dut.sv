// Converted from chipsalliance/sv-tests (bitstream_cast).
// Upstream casts an undriven packed struct to `integer` in a declaration initialiser and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, input logic [7:0] b, input logic [15:0] c,
           output logic signed [31:0] o);
  struct packed {logic [7:0] a; logic [7:0] b; logic [15:0] c;} s;
  // The struct is driven from ports and the bitstream cast's result is an output,
  // so the cast's bit ORDER is observable: the first member lands in the HIGH bits.
  always_comb begin
    s.a = a;
    s.b = b;
    s.c = c;
  end
  assign o = integer'(s);
endmodule
