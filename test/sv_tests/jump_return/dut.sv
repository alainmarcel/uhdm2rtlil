// Converted from chipsalliance/sv-tests (jump_return).
// Upstream's void function only `$display`s, so whether the early bare `return` skipped the rest of the body is invisible to synthesis.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module jump_tb (input logic signed [31:0] a, output logic signed [31:0] o);
  // Upstream's construct is a VOID function with a BARE `return`, kept as such:
  // the early return must skip the second write, so the argument 21 leaves the
  // output at the first value and anything else reaches the second.
  function automatic void fun(input int a, output int r);
    r = 1;
    if(a == 21)
      return;
    r = 2;
  endfunction
  always_comb fun(a, o);
endmodule
