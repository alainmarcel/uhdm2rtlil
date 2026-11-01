// Converted from chipsalliance/sv-tests (operations-on-unpacked-arrays-rw).
// Upstream fills the array from three assignment patterns inside an `initial` block and prints its elements, so synthesis sees only constants it never reads.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] x, output bit [7:0] o);
  bit arr_a [7:0];
  // An assignment pattern fills the array MSB-index first, so bit i of the port
  // vector has to reach element i for the round trip below to hold.
  always_comb
    for (int i = 0; i < 8; i++) arr_a[i] = x[i];
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_a[i];
endmodule
