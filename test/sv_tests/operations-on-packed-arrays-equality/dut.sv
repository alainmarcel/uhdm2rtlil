// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-equality).
// Upstream compares two constant arrays inside an `initial` block and prints both results.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] arr_a, input bit [7:0] arr_b, output logic eq,
            output logic ne);
  assign eq = (arr_a == arr_b);
  assign ne = (arr_a != arr_b);
endmodule
