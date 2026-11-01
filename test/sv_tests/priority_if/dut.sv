// Converted from chipsalliance/sv-tests (priority_if).
// Upstream ties the selector to 0 and never reads `b`, so neither arm of the `priority if` is exercised -- and with no final `else` the variable holds, which nothing observes.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module if_tb (input wire [3:0] a, input reg [1:0] bin, output reg [1:0] b);
  // `priority if` keeps the arms in source ORDER, so the first true condition wins;
  // the hold value comes from a port because upstream has no final else.
  always @* begin
    b = bin;
    priority if(a[0] == 0) b = 1;
    else if(a[1] == 0) b = 2;
  end
endmodule
