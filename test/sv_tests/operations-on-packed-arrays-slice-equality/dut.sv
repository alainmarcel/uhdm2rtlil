// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-slice-equality).
// Upstream compares two SLICES of constant arrays inside an `initial` block and prints both results.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, input bit [7:0] arr_b, output logic eq,
            output logic ne);
  // The slices are at DIFFERENT offsets, so a comparison that ignored one of the
  // offsets would still pass upstream's single vector -- hence the second one.
  assign eq = (arr_a[7:4] == arr_b[3:0]);
  assign ne = (arr_a[7:4] != arr_b[3:0]);
endmodule
