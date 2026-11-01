// Converted from chipsalliance/sv-tests (enum_sequence).
// Upstream declares a RANGED enum (`step[10]`) and never reads any of its members, so neither the base value nor the generated sequence is checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] st, output logic signed [31:0] s0,
           output logic signed [31:0] s1, output logic signed [31:0] s9);
  enum {start=10, step[10]} e;
  // `step[10]` generates step0..step9, numbered on from `start`, so the names must
  // exist AND carry 11..20.
  assign st = start;
  assign s0 = step0;
  assign s1 = step1;
  assign s9 = step9;
endmodule
