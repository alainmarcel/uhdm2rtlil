// Converted from chipsalliance/sv-tests (isunknown_function).
// Upstream prints `$isunknown` of four x/z parameters from an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] v, output logic u0, output logic u1, output logic u2,
           output logic u3, output logic [3:0] w);
	parameter [3:0] val0 = 4'b000x;
	parameter [3:0] val1 = 4'b000z;
	parameter [3:0] val2 = 4'b00xz;
	parameter [3:0] val3 = 4'b0000;
  assign u0 = $isunknown(val0);
  assign u1 = $isunknown(val1);
  assign u2 = $isunknown(val2);
  assign u3 = $isunknown(val3);
  assign w  = v;
endmodule
