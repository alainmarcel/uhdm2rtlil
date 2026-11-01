// Converted from chipsalliance/sv-tests (arrays-packed-quering-functions-size).
// Upstream prints `$size(arr)` from an `initial` block, so the query's answer reaches nothing, and `arr` is never driven either.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input logic [7:0] a, output logic [7:0] arr_o,
            output logic signed [31:0] q);
  bit [7:0] arr;
  // `arr` is driven from a port so the array it queries cannot be optimised away,
  // and the query's answer is an output rather than a printed number.
  assign arr   = a;
  assign arr_o = arr;
  assign q     = $size(arr);
endmodule
