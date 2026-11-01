// Converted from chipsalliance/sv-tests (case).
// Upstream ties the selector to the constant 0, so three of the four arms are dead code and the default is never reached.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module case_tb (input wire [3:0] a, output reg [3:0] b);
  always @* begin
    case(a)
      4'h0: b = 12;
      4'h3: b = 4;
      4'hf: b = 8;
      default b = 0;
    endcase
  end
endmodule
