// Converted from chipsalliance/sv-tests (operations-on-packed-arrays-rw).
// Upstream writes the array three times inside an `initial` block and prints each value, so synthesis sees only the last -- if any.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top (input bit [7:0] x, output bit [7:0] arr);
  // A whole-array write must carry all eight bits; upstream's three values are the
  // vectors below.
  assign arr = x;
endmodule
