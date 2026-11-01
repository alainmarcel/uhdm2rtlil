// Converted from chipsalliance/sv-tests (integers-unsized).
// Upstream assigns three UNSIZED literals -- decimal, hex and octal -- to the same variable inside an `initial` block, so only the last would survive and none is read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [31:0] a_dec, output logic [31:0] a_hex,
           output logic [31:0] a_oct);
  // Each unsized literal gets its own output, so all three are observable rather
  // than overwriting one another.  An unsized literal is 32 bits wide.
  assign a_dec = 659;
  assign a_hex = 'h 837FF;
  assign a_oct = 'o7460;
endmodule
