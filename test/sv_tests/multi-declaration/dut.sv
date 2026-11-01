// Converted from chipsalliance/sv-tests (multi-declaration).
// Upstream declares two arrays of different shapes in ONE declaration and never drives or reads either, so nothing confirms each got its own dimensions.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] [31:0] x, input bit [7:0] [31:0] y,
            output bit [7:0] [31:0] a_o, output bit [7:0] [31:0] b_o,
            output logic signed [31:0] a_bits, output logic signed [31:0] b_bits);
  // Same packed dimensions, DIFFERENT unpacked ones, in a single declaration.
  bit [7:0] [31:0] arr_a [1:5] [1:10], arr_b [0:255];
  // An element of each round-trips and $bits reads the shared packed geometry back,
  // so a declaration that gave the second name the first one's unpacked dims -- or
  // dropped its own -- is visible.
  always_comb begin
    arr_a[1][1] = x;
    arr_b[0]    = y;
  end
  assign a_o    = arr_a[1][1];
  assign b_o    = arr_b[0];
  assign a_bits = $bits(arr_a[1][1]);
  assign b_bits = $bits(arr_b[0]);
endmodule
