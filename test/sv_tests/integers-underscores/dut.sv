// Converted from chipsalliance/sv-tests (integers-underscores).
// Upstream assigns three literals containing UNDERSCORES (and, in one, spaces around the base) inside an `initial` block and never reads them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [31:0] a, output logic [15:0] b, output logic [31:0] c);
  // The underscores are digit separators and must not change the value; the third
  // literal also has spaces around its base, which must be accepted.
  assign a = 27_195_000;
  assign b = 16'b0011_0101_0001_1111;
  assign c = 32 'h 12ab_f001;
endmodule
