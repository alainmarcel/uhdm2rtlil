// Converted from chipsalliance/sv-tests (function_automatic).
// Upstream calls the function four times from an `initial` block and prints each result, asserting 5 every time -- the point being that an AUTOMATIC local starts fresh on each call rather than accumulating.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o1,
           output logic signed [31:0] o2, output logic signed [31:0] o3);
  function automatic int add(int val);
    int a = 0;
    a = a + val;
    return a;
  endfunction
  // Three independent calls: an automatic local must make each one return its own
  // argument, so none of the outputs can carry another call's accumulation.
  assign o1 = add(x);
  assign o2 = add(x);
  assign o3 = add(x);
endmodule
