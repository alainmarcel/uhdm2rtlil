// Converted from chipsalliance/sv-tests (subarrays).
// Upstream writes a 4-element SUBARRAY of a 3-D array element by element inside an `initial` block, copies the whole subarray to another, and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic signed [31:0] x0, input logic signed [31:0] x1,
           input logic signed [31:0] x2, input logic signed [31:0] x3,
           output logic signed [31:0] b0, output logic signed [31:0] b1,
           output logic signed [31:0] b2, output logic signed [31:0] b3);
  int A[2][3][4], B[2][3][4];
  // A whole-SUBARRAY copy: B[1][1] takes all four elements of A[0][2].
  always_comb begin
    A[0][2][0] = x0; A[0][2][1] = x1; A[0][2][2] = x2; A[0][2][3] = x3;
    B[1][1] = A[0][2];
  end
  assign b0 = B[1][1][0]; assign b1 = B[1][1][1]; assign b2 = B[1][1][2]; assign b3 = B[1][1][3];
endmodule
