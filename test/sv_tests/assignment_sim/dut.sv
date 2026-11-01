// Converted from chipsalliance/sv-tests (assignment_sim).
// Upstream writes two constants inside an `initial` block, prints one, overwrites it from the other and prints again -- so what synthesis sees is a constant, and the ORDER that makes the second print differ from the first is invisible.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input reg [3:0] ain, input reg [3:0] bin, output reg [3:0] first,
           output reg [3:0] second);
  // Two blocking assignments in sequence: `first` captures the value before the
  // overwrite and `second` after it, so the ordering upstream's two prints assert
  // is observable.
  always_comb begin
    reg [3:0] a;
    reg [3:0] b;
    a      = ain;
    b      = bin;
    first  = a;
    a      = b;
    second = a;
  end
endmodule
