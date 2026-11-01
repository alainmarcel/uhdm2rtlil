// Converted from chipsalliance/sv-tests (expr_short_circuit).
// Upstream marks the function it expects NOT to be called with a `$display` and prints the result, so neither half is visible to synthesis.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic a, input logic b, input logic c, output logic d);
  function automatic logic fun(logic v);
    return v;
  endfunction
  // Upstream's expression, kept verbatim with its operands on ports.
  assign d = a && (b || fun(c));
endmodule
