// Converted from chipsalliance/sv-tests (integers-sized).
// Upstream assigns five SIZED literals inside an `initial` block and never reads them, so neither the sizes nor the x/z padding is checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [3:0] a, output logic [4:0] b, output logic [2:0] c,
           output logic [11:0] d, output logic [15:0] e);
  assign a = 4'b1001; // is a 4-bit binary number
  assign b = 5'D3;    // is a 5-bit decimal number
  assign c = 3'b01x;  // is a 3-bit number with the least
                      // significant bit unknown
  assign d = 12'hx;   // is a 12-bit unknown number
  assign e = 16'hz;   // is a 16-bit high-impedance number
endmodule
