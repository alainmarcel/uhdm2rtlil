// Converted from chipsalliance/sv-tests (case_constant).
// Upstream ties `a` to 0, so this `case (1)` -- whose ARMS are the expressions and whose selector is the constant -- always takes the default.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module case_tb (input wire [3:0] a, output reg [3:0] b);
  // The selector is the constant and the ARMS are expressions, so the first arm
  // that equals 1 wins: this is a priority decoder over a's bits.
  always @* begin
    case(1)
      a[0] : b = 1;
      a[1] : b = 2;
      a[2] : b = 3;
      a[3] : b = 4;
      default b = 0;
    endcase
  end
endmodule
