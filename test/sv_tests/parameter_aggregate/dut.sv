// Converted from chipsalliance/sv-tests (parameter_aggregate).
// Upstream declares an UNPACKED-ARRAY parameter with an assignment pattern and never reads any element.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [31:0] e0, output logic [31:0] e1,
           output logic [31:0] e2, output logic [31:0] e3);
  parameter logic [31:0] p [3:0] = '{1, 2, 3, 4};
  // The pattern fills the array MSB-index first, so element 3 takes the FIRST value.
  // Reading all four pins both the values and the order.
  assign e0 = p[0];
  assign e1 = p[1];
  assign e2 = p[2];
  assign e3 = p[3];
endmodule
