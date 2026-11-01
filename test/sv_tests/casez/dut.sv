// Converted from chipsalliance/sv-tests (casez).
// Upstream ties the selector to the constant `4'b1z11`, so only the first arm is ever reached and the z wildcards in the other arms are never exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module case_tb (input wire [3:0] a, output reg [3:0] b);
  // In a casez only z (and ?) in an ARM is don't-care -- x is NOT -- so each arm
  // matches on its leading ones alone.
  always @* begin
    casez(a)
      4'b1zzz: b = 1;
      4'b01z?: b = 2;
      4'b001z: b = 3;
      4'b0001: b = 4;
      default b = 0;
    endcase
  end
endmodule
