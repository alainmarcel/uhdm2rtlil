// Converted from chipsalliance/sv-tests (22.8--default_nettype, :type: preprocessing).
// Upstream is the directive ALONE, with no module.  `default_nettype wire is
// genuinely observable: it is what makes an UNDECLARED identifier on an assign's
// LHS a legal implicit net, so the directive is kept verbatim and the body now
// relies on exactly that.  Under `default_nettype none the same body does not
// compile, which is the difference the test is for.
// Upstream kept as orig.sv.
`default_nettype wire
module top(input logic a, input logic b, output logic o);
  assign implicit_net = a & b;   // legal ONLY because the net type defaults to wire
  assign o = implicit_net;
endmodule
