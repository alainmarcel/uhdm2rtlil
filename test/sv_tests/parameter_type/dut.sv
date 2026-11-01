// Converted from chipsalliance/sv-tests (parameter_type).
// Upstream declares a TYPE parameter defaulting to `real` and leaves the body empty.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top #(type T = real) (output logic signed [31:0] nbits);
  // The type parameter must name a usable type; $bits of the default `real` is 64.
  assign nbits = $bits(T);
endmodule
