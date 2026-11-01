// Converted from chipsalliance/sv-tests (casex).
// Upstream ties the selector to the constant `4'b10zx`, so only the first arm is ever reached and the x/z WILDCARDS in the other arms are never exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module case_tb (input wire [3:0] a, output reg [3:0] b);
  // In a casex, x and z in an ARM are don't-care, so each arm matches on its leading
  // ones alone: a real selector is what makes that visible.
  always @* begin
    casex(a)
      4'b1xz?: b = 1;
      4'b01xx: b = 2;
      4'b001x: b = 3;
      4'b0001: b = 4;
      default b = 0;
    endcase
  end
endmodule
