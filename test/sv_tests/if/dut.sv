// Converted from chipsalliance/sv-tests (if).
// Upstream ties the condition to the constant 0, so the `if` body is dead code -- and with no `else` the variable keeps its value, which nothing reads.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module if_tb (input wire a, input reg bin, output reg b);
  // An `if` with NO else and an incomplete assignment: b has to hold its previous
  // value, which is what makes this a latch rather than a mux.  The hold value
  // comes from a port so it is observable.
  always @* begin
    b = bin;
    if(a) b = 1;
  end
endmodule
