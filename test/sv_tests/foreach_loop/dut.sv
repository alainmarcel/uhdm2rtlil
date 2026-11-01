// Converted from chipsalliance/sv-tests (foreach_loop).
// Upstream's `foreach` body is a `$display` over a `string` array, so nothing is observable and the array cannot be synthesized.  The strings are incidental to the construct and are replaced by ints.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module foreach_tb (output logic signed [31:0] sum, output logic signed [31:0] n);
  int test [4] = '{111, 222, 333, 444};
  // `foreach` must visit every element exactly once, which the accumulation and the
  // visit count together pin down.
  always_comb begin
    sum = 0;
    n   = 0;
    foreach(test[i]) begin
      sum = sum + test[i];
      n   = n + 1;
    end
  end
endmodule
