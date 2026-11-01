// Converted from chipsalliance/sv-tests (ceil_function).
// Upstream prints `$ceil(3.7)` from an `initial` block, so the answer reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o);
  // $ceil is evaluated in real arithmetic at elaboration; the int cast makes its
  // answer something a netlist can carry.
  assign o = int'($ceil(3.7));
endmodule
