// Converted from chipsalliance/sv-tests (arrays).
// Upstream declares the array with its assignment pattern and never reads it, so nothing checks what the pattern filled in -- in particular the `'{3{4}}` replication of the second row.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] e11, output logic signed [31:0] e12,
           output logic signed [31:0] e13, output logic signed [31:0] e21,
           output logic signed [31:0] e22, output logic signed [31:0] e23);
  int n[1:2][1:3] = '{'{0,1,2},'{3{4}}};
  // Every element the pattern fills is read out, so a replication that expanded
  // to the wrong count or a row that landed in the wrong place is visible.
  assign e11 = n[1][1];
  assign e12 = n[1][2];
  assign e13 = n[1][3];
  assign e21 = n[2][1];
  assign e22 = n[2][2];
  assign e23 = n[2][3];
endmodule
