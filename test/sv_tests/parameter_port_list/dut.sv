// Converted from chipsalliance/sv-tests (parameter_port_list).
// Upstream declares the parameter in the module's PARAMETER PORT LIST and leaves the body empty.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top #(p = 12) (output logic signed [31:0] o);
  assign o = p;
endmodule
