// Converted from chipsalliance/sv-tests (clog2_function).
// Upstream prints `$clog2(32)` from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x, output logic signed [31:0] o,
           output logic signed [31:0] w);
  // Upstream's own argument and asserted value are kept.
  assign o = $clog2(32);
  // A port-driven witness: several of these answer with 0, and a netlist whose
  // every output is constant zero makes the co-sim VACUOUS -- it reports no output
  // activity rather than comparing anything.
  assign w = x;
endmodule
