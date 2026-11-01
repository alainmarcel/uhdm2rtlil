// Converted from chipsalliance/sv-tests (integers-left-padding-bit).
// Upstream assigns the four UNBASED UNSIZED fill literals inside an `initial` block and never reads them, so the fill is never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [15:0] a, output logic [15:0] b, output logic [15:0] c,
           output logic [15:0] d);
  assign a = '0; // sets all 16 bits to 0
  assign b = '1; // sets all 16 bits to 1
  assign c = 'x; // sets all 16 bits to x
  assign d = 'z; // sets all 16 bits to z
endmodule
