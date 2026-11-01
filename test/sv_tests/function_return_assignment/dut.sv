// Converted from chipsalliance/sv-tests (function_return_assignment).
// Upstream prints the call's result from an `initial` block on constant arguments.  The construct is returning by ASSIGNING THE FUNCTION NAME rather than by `return`.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] a, input logic signed [31:0] b,
           output logic signed [31:0] o);
  function int add(int a, int b);
    add = a + b;
  endfunction
  assign o = add(a, b);
endmodule
