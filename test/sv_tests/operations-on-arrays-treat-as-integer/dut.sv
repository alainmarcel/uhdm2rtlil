// Converted from chipsalliance/sv-tests (operations-on-arrays-treat-as-integer).
// Upstream does the arithmetic on constants inside an `initial` block and prints it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, output bit [7:0] arr_b);
  // A packed array used in arithmetic is treated as an INTEGER of its width, so the
  // add must carry across the whole 8 bits and wrap there.
  assign arr_b = (arr_a + 29);
endmodule
