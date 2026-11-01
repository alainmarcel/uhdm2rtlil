// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-one-bit).
// Upstream copies ONE bit between two constant arrays inside an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  // A single-bit write must land on bit 5 and leave every other bit of the
  // destination alone, which the port-supplied base makes observable.
  always_comb begin
    arr_b    = base;
    arr_b[5] = arr_a[2];
  end
endmodule
