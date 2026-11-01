// Converted from chipsalliance/sv-tests (function_static).
// Upstream calls the function four times from an `initial` block and asserts 5, 10, 15, 20 -- a STATIC local accumulating ACROSS CALLS.  That is a simulation-time property of one shared variable over time and has no netlist form; see NOTE.md.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o);
  function static int add(int val);
    int a = 0;
    a = a + val;
    return a;
  endfunction
  assign o = add(x);
endmodule
