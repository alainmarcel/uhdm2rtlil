// Converted from chipsalliance/sv-tests (repeat_loop).
// Upstream's `repeat` body is a `$display`, so the loop does nothing a netlist can see.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module repeat_tb (output logic signed [31:0] n);
  // Upstream's count is a VARIABLE, which no frontend unrolls (read_verilog:
  // "Repeat loops outside must have constant repetition count"), so the count is
  // upstream's own 128 as a literal -- the synthesizable form of the same loop.
  always_comb begin
    n = 0;
    repeat(128)
      n = n + 1;
  end
endmodule
