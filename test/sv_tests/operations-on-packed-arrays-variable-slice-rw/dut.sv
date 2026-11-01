// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-variable-slice-rw).
// Upstream copies an INDEXED part-select whose width comes from a parameter, inside an `initial` block on constants, and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, input bit [7:0] base, output bit [7:0] arr_b);
  parameter integer c = 3;
  // The WIDTH comes from a parameter and the two offsets differ, so the copy has to
  // take c bits from offset 1 and place them at offset 4.
  always_comb begin
    arr_b       = base;
    arr_b[4+:c] = arr_a[1+:c];
  end
endmodule
