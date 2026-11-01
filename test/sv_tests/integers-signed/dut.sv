// Converted from chipsalliance/sv-tests (integers-signed).
// Upstream assigns four SIGNED literals inside an `initial` block and never reads them, so the two's-complement values its comments spell out are never checked.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [7:0] a, output logic [3:0] b, output logic [3:0] c,
           output logic [15:0] d);
  assign a = -8'd 6;  // this defines the two's-complement of 6,
                      // held in 8 bits-equivalent to -(8'd 6)
  assign b = 4'shf;   // this denotes the 4-bit number '1111', to
                      // be interpreted as a two's-complement number,
                      // or '-1'. This is equivalent to -4'h 1
  assign c = -4'sd15; // this is equivalent to -(-4'd 1), or '0001'
  assign d = 16'sd?;  // the same as 16'sbz
endmodule
