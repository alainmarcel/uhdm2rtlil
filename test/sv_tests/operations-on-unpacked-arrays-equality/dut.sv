// Converted from chipsalliance/sv-tests (operations-on-unpacked-arrays-equality).
// Upstream compares two constant unpacked arrays inside an `initial` block and prints both results.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] x, input bit [7:0] y, output logic eq, output logic ne);
  bit arr_a [7:0];
  bit arr_b [7:0];
  always_comb
    for (int i = 0; i < 8; i++) begin
      arr_a[i] = x[i];
      arr_b[i] = y[i];
    end
  // Whole-ARRAY equality on an UNPACKED array compares element by element.
  assign eq = (arr_a == arr_b);
  assign ne = (arr_a != arr_b);
endmodule
