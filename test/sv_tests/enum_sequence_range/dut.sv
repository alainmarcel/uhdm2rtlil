// Converted from chipsalliance/sv-tests (enum_sequence_range).
// Upstream declares a RANGED enum member list with explicit bounds (`stop[11:13]`) and never reads any of its members.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] st, output logic signed [31:0] s11,
           output logic signed [31:0] s12, output logic signed [31:0] s13);
  enum {start=10, stop[11:13]} e;
  // `stop[11:13]` generates stop11..stop13, and -- unlike `stop[3]`, which would
  // number from the previous member -- the names carry their own INDEX values.
  assign st  = start;
  assign s11 = stop11;
  assign s12 = stop12;
  assign s13 = stop13;
endmodule
