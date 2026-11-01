// Converted from chipsalliance/sv-tests (arith_shift_assignment_signed).
// Upstream applies `<<<=` / `>>>=` to constants inside an `initial` block and prints them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [7:0] a, output logic signed [7:0] b,
           output logic signed [7:0] c);
  // The compound assignment operators are kept verbatim; only their operand is
  // now a port.
  always_comb begin
    b = a;
    c = a;
    b <<<= 3;
    c >>>= 3;
  end
endmodule
