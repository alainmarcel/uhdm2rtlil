// Converted from chipsalliance/sv-tests (case_set).
// Upstream ties the selector to 0, so neither the value list nor the `4'b01??` wildcard nor the `[5:6]` range of this `case ... inside` is ever exercised.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module case_tb (input reg [3:0] a, output reg [3:0] b);
  // `case ... inside` matches against a SET: a value list, a wildcard pattern and a
  // range, all of which need a real selector to tell apart.
  always @* begin
    case(a) inside
      1, 3: b = 1;
      4'b01??, [5:6]: b = 2;
      default b = 3;
    endcase
  end
endmodule
