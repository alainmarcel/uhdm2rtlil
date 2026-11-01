// Converted from chipsalliance/sv-tests (assert0_test).
// Upstream ties `a` to the constant 1, so a deferred `assert #0` is vacuously true and a frontend that dropped it entirely would look identical.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic a, output logic o);
  assert #0 (a != 0);
  // The condition is a PORT, so the assertion is a real one, and the passthrough
  // gives the netlist an output that actually moves.
  assign o = a;
endmodule
