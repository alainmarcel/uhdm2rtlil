// Converted from chipsalliance/sv-tests (parameter_dep).
// Upstream declares one parameter in terms of another and reads neither.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o1, output logic signed [31:0] o2);
  parameter p1 = 123;
  parameter p2 = p1 * 3;
  // The dependent parameter must be folded at elaboration from the first one.
  assign o1 = p1;
  assign o2 = p2;
endmodule
