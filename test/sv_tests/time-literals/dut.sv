// Converted from chipsalliance/sv-tests (time-literals).
// Upstream assigns seven TIME LITERALS to a `time` variable inside an `initial` block, under a 100ps/10ps timescale, and never reads it.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`timescale 100ps/10ps
module top(input logic x, output logic [63:0] t_ns, output logic [63:0] t_us,
           output logic [63:0] t_ms, output logic [63:0] t_real, output logic w);
  // A time literal is scaled to the module's time unit (100ps): 1ns is 10 units,
  // 1us is 10000, 1ms is 10000000, and the real 2.1ms rounds to 21000000.
  assign t_ns   = 1ns;
  assign t_us   = 1us;
  assign t_ms   = 1ms;
  assign t_real = 2.1ms;
  assign w = x;
endmodule
