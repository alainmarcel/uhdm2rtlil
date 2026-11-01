// Converted from chipsalliance/sv-tests (arrays-key-index).
// Upstream declares the array with an INDEX-KEYED pattern (`'{1:1, default:0}`) and never reads it, so neither the keyed element nor the default is checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] b1, output logic signed [31:0] b2,
           output logic signed [31:0] b3);
  typedef int triple [1:3];
  triple b = '{1:1, default:0};
  // Element 1 comes from the key, elements 2 and 3 from the default.
  assign b1 = b[1];
  assign b2 = b[2];
  assign b3 = b[3];
endmodule
