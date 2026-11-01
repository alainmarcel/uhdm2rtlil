// Converted from chipsalliance/sv-tests (if_else).
// Upstream ties the condition to the constant 0, so the true arm is dead code and the result is never read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module if_tb (input wire a, output reg b);
  always @* begin
    if(a) b = 1;
    else b = 0;
  end
endmodule
