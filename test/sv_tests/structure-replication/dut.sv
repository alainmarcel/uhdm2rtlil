// Converted from chipsalliance/sv-tests (structure-replication).
// Upstream initialises a struct with a REPLICATION pattern and never reads it; the nested array-of-structs part lives in an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] X, output logic signed [31:0] Y,
           output logic signed [31:0] Z);
  struct {int X,Y,Z;} XYZ = '{3{1}};
  // '{3{1}} fills all three members with 1.
  assign X = XYZ.X; assign Y = XYZ.Y; assign Z = XYZ.Z;
endmodule
