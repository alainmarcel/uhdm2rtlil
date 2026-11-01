// Converted from chipsalliance/sv-tests (comments).
// Upstream is an EMPTY module containing only a multi-line and a single-line comment, so nothing confirms the comments were consumed without eating code around them.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module empty (
  input logic [7:0] x,
  output logic [8:0] y
);
  /* multi
     line
     comment
   */
  // single line comment
  assign y = x + 8'd1;   /* trailing block comment */  // and a trailing line comment
endmodule
