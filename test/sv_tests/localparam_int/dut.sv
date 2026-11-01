// Converted from chipsalliance/sv-tests (localparam_int).
// Upstream declares the localparam and never reads it, so its value reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o);
  localparam int p = 123;
  assign o = p;
endmodule
