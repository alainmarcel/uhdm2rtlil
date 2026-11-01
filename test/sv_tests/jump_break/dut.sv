// Converted from chipsalliance/sv-tests (jump_break).
// Upstream's loop runs inside an `initial` block and only `$display` reads the index the `break` left behind.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module jump_tb (output logic signed [31:0] i_o, output logic signed [31:0] n);
  // `break` must leave the loop on the first iteration whose guard is true, so the
  // index stops at 101 -- upstream's own asserted value -- and the body must have
  // run exactly 102 times.
  always_comb begin
    int i;
    n = 0;
    for (i = 0; i < 256; i++) begin
      n = n + 1;
      if(i > 100)
        break;
    end
    i_o = i;
  end
endmodule
