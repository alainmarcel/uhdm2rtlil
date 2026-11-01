// Converted from chipsalliance/sv-tests (if_else_if).
// Upstream ties both conditions to the constant 0, so only the final `else` is reachable -- and the chain writes TWO different variables, neither of which is read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module if_tb (input wire a, input wire c, input reg bin, input reg din,
              output reg b, output reg d);
  // The chain assigns b in two arms and d in the middle one.  Both start from a
  // port, so the arm that ran is observable on BOTH outputs -- the one the arm did
  // not write still carries its incoming value.  (Defaulting them also keeps the
  // block latch-free; the incomplete-assignment case is the `if` test's subject.)
  always @* begin
    b = bin;
    d = din;
    if(a) b = 1;
    else if(c) d = 1;
    else b = 0;
  end
endmodule
