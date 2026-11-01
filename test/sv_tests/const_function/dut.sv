// Converted from chipsalliance/sv-tests (const_function).
// Upstream prints the localparam from an `initial` block, so nothing checks that the function was actually evaluated at elaboration.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o, output logic signed [31:0] w);
  localparam a = fun(3);
  function int fun(int val);
    return val + 1;
  endfunction
  // The localparam's value is the function's RESULT, computed at elaboration: it has
  // to reach the netlist as the constant 4, which upstream asserts.
  assign o = a;
  // A second call at a different argument, so a function that returned its
  // argument unchanged could not pass both.
  assign w = fun(10);
endmodule
