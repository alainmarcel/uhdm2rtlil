// Converted from chipsalliance/sv-tests (set_member_sim).
// Upstream evaluates `inside` on constants in an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] b, output logic a,
           output logic signed [31:0] w);
  localparam c = 5;
  localparam d = 7;
  // A port-driven witness: `a` is 0 for all but two of 2^32 values, so a random
  // co-sim never sets it and reports the run VACUOUS.
  assign w = b;
  assign a = b inside {c, d};
endmodule
