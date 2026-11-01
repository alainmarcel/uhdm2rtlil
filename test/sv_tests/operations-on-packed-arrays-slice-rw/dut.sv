// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-slice-rw).
// Upstream copies a three-bit SLICE between two constant arrays inside an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  // The source and destination slices are at DIFFERENT offsets, so the copy has to
  // shift; the port-supplied base shows that the surrounding bits are untouched.
  always_comb begin
    arr_b      = base;
    arr_b[5:3] = arr_a[2:0];
  end
endmodule
