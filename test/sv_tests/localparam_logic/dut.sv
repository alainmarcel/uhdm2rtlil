// Converted from chipsalliance/sv-tests (localparam_logic).
// Upstream declares the localparam and never reads it, so its value reaches nothing.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] o, output logic signed [31:0] w);
  localparam [10:0] p = 1 << 5;
  localparam logic [10:0] q = 1 << 5;
  assign o = p;
  assign w = q;
endmodule
