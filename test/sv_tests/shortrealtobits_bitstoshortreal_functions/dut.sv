// Converted from chipsalliance/sv-tests (shortrealtobits_bitstoshortreal_functions).
// Upstream round-trips 12.45 through `$shortrealtobits`/`$bitstoshortreal` and checks it within 0.001, inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic x, output logic ok, output logic w);
	shortreal s;
  always_comb s = $bitstoshortreal($shortrealtobits(12.45));
  assign ok = (s > 12.449 && s < 12.451);
  assign w  = x;
endmodule
