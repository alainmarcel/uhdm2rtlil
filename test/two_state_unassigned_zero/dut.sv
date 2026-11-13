// povik/sv-elab#222: a 2-state variable the source never assigns keeps its
// initial value 0 for ever (LRM 6.8).  `w1` is a `bit` output nothing
// writes, `k` a never-written `int` read into `r`; read_uhdm left both
// undriven, so they read X where the RTL reads 0.  `a_out` is assigned and
// must stay so.
module top(output bit [3:0] w1, input bit w2, output bit a_out,
           output logic [31:0] r);
  int k;
  assign a_out = ~w2;
  assign r = k + 1;
endmodule
