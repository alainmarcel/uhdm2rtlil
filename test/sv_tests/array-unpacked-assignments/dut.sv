// Converted from chipsalliance/sv-tests (array-unpacked-assignments).
// Upstream fills A element by element inside an `initial` block, copies the whole array to B and prints B.  The ranges are REVERSED (`A [3:0]` vs `B [0:3]`), which is the point, and nothing checks it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] a0, input logic signed [31:0] a1,
           input logic signed [31:0] a2, input logic signed [31:0] a3,
           output logic signed [31:0] b0, output logic signed [31:0] b1,
           output logic signed [31:0] b2, output logic signed [31:0] b3);
  int A [3:0];
  int B [0:3];
  always_comb begin
    A[0] = a0;
    A[1] = a1;
    A[2] = a2;
    A[3] = a3;
    B = A;          // whole-array copy between REVERSED ranges
  end
  assign b0 = B[0];
  assign b1 = B[1];
  assign b2 = B[2];
  assign b3 = B[3];
endmodule
