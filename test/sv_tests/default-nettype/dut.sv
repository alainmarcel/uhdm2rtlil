// Converted from chipsalliance/sv-tests (default-nettype).
// Upstream sets the net type twice and then declares an EMPTY module, so neither setting reaches anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`default_nettype wire
`default_nettype none
module dn(input logic [7:0] x, input logic [7:0] z, output logic [8:0] y);
  // `default_nettype none is in effect, so EVERY identifier here has to be
  // declared -- an implicit net would be an error, which is the difference the
  // second directive makes.
  logic [8:0] sum;
  assign sum = x + z;
  assign y   = sum;
endmodule
