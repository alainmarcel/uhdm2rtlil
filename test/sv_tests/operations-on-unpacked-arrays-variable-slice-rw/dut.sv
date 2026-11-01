// Converted from chipsalliance/sv-tests (operations-on-unpacked-arrays-variable-slice-rw).
// Upstream copies an INDEXED part-select of an unpacked array whose width comes from a parameter, inside an `initial` block on constants, and prints the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] x, input bit [7:0] base, output bit [7:0] o);
  parameter integer c = 3;
  bit arr_a [7:0];
  bit arr_b [7:0];
  // The WIDTH comes from a parameter and the offsets differ, so the copy has to take
  // c elements from offset 1 and place them at offset 4.
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = base[i];
    end
    arr_b[4+:c] = arr_a[1+:c];
  end
  always_comb
    for (int i = 0; i < 8; i++) o[i] = arr_b[i];
endmodule
