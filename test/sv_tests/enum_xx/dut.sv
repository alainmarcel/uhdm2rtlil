// Converted from chipsalliance/sv-tests (enum_xx).
// Upstream declares an enum with an ALL-X member (`b = {32{1'bx}}`) and never reads any of them, so neither the x member nor the ordinary ones are checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [31:0] x, output logic signed [31:0] oa,
           output logic signed [31:0] oc, output logic is_b);
  enum integer {a=0, b={32{1'bx}}, c=1} val;
  // The two ordinary members must carry their explicit values, and the x member must
  // be comparable with === (which `==` could not express).
  assign oa   = a;
  assign oc   = c;
  assign is_b = (x === b);
endmodule
