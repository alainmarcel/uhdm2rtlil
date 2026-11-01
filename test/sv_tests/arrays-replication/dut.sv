// Converted from chipsalliance/sv-tests (arrays-replication).
// Upstream declares the array with a NESTED replication pattern and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] r1c1, output logic signed [31:0] r1c2,
           output logic signed [31:0] r1c5, output logic signed [31:0] r1c6,
           output logic signed [31:0] r2c1, output logic signed [31:0] r2c6);
  int n[1:2][1:6] = '{2{'{3{4, 5}}}};
  // '{3{4, 5}} is the six-element row 4,5,4,5,4,5 and the outer 2{} repeats it for
  // both rows: reading the ends of each row pins both replications.
  assign r1c1 = n[1][1];
  assign r1c2 = n[1][2];
  assign r1c5 = n[1][5];
  assign r1c6 = n[1][6];
  assign r2c1 = n[2][1];
  assign r2c6 = n[2][6];
endmodule
