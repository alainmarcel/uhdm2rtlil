// Converted from chipsalliance/sv-tests (function_recursive).
// Upstream prints five factorials from an `initial` block, so the recursion's results reach nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] f0, output logic signed [31:0] f1,
           output logic signed [31:0] f2, output logic signed [31:0] f5,
           output logic signed [31:0] f11);
  function automatic int factorial(int val);
    if(val == 0) return 1;
    return factorial(val-1) * val;
  endfunction
  // The arguments must stay constants: the recursion has to be unrolled at
  // elaboration, which is only possible for a known depth.
  assign f0  = factorial(0);
  assign f1  = factorial(1);
  assign f2  = factorial(2);
  assign f5  = factorial(5);
  assign f11 = factorial(11);
endmodule
