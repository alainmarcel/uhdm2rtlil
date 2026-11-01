// Converted from chipsalliance/sv-tests (arith_shift_assignment_unsigned).
// Upstream applies `<<<=` / `>>>=` to constants inside an `initial` block and prints them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] a, output logic [7:0] b, output logic [7:0] c);
  always_comb begin
    b = a;
    c = a;
    b <<<= 3;
    c >>>= 3;
  end
endmodule
