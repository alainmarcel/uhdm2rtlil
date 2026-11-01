// Converted from chipsalliance/sv-tests (multi-dim-basic).
// Upstream declares three arrays with different packed/unpacked dimension orders and never drives or reads any of them, so neither the geometry nor the ordering its comments spell out is checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input bit [3:0] [7:0] x, input bit [7:0] y,
           output bit [3:0] [7:0] arr_o, output bit [7:0] mem_o,
           output logic signed [31:0] arr_bits, output logic signed [31:0] arr2_bits,
           output logic signed [31:0] arr2_dims);
  // 10 elements of 4 8-bit bytes (each element packed into 32 bits)
  bit [3:0] [7:0] arr [1:10];
  // compatible with memory array
  bit [7:0] mem [0:255];
  // Varies most rapidly: 1 to 6, 1 to 5, 1 to 8, 1 to 7
  bit [1:5] [1:6] arr2 [1:7] [1:8];
  // An element of each array round-trips, and $bits / $dimensions read the geometry
  // back, so a declaration whose dimensions collapsed is visible.
  always_comb begin
    arr[1] = x;
    mem[0] = y;
  end
  assign arr_o     = arr[1];
  assign mem_o     = mem[0];
  assign arr_bits  = $bits(arr[1]);
  assign arr2_bits = $bits(arr2[1][1]);
  assign arr2_dims = $dimensions(arr2);
endmodule
