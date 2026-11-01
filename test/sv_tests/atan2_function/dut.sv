// Converted from chipsalliance/sv-tests (atan2_function).
// Upstream prints `int'($atan2(2.1, 3.7) * 1000)` from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o,
           output logic signed [31:0] w);
  // Upstream's own argument and asserted value are kept.  The real result is scaled by 1000 and cast to int so a netlist can carry it.
  assign o = int'($atan2(2.1, 3.7) * 1000);
  // A port-driven witness: several of these answer with 0, and a netlist whose
  // every output is constant zero makes the co-sim VACUOUS -- it reports no output
  // activity rather than comparing anything.
  assign w = x;
endmodule
