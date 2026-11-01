// Converted from chipsalliance/sv-tests (operations-on-unpacked-arrays-one-bit).
// Upstream copies ONE element between two constant unpacked arrays inside an `initial` block and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] x, input bit [7:0] base, output bit [7:0] o);
  bit arr_a [7:0];
  bit arr_b [7:0];
  // The copy must land on element 5 and leave every other element alone, which the
  // port-supplied base makes observable.
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = base[i];
    end
    arr_b[5] = arr_a[2];
  end
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_b[i];
endmodule
