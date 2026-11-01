// Converted from chipsalliance/sv-tests (initial).
// Upstream's `initial a = 1;` is the whole module: `a` is never read, so nothing confirms the initial value reached the netlist.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module initial_tb (input logic clk, input logic d, output reg a);
  // The `initial` block is the register's POWER-UP value, which a frontend carries
  // as the wire's `init` attribute; the always block makes `a` a real register so
  // there is something for that value to initialise.
  initial
    a = 1;
  always @(posedge clk)
    a <= d;
endmodule
