// Converted from chipsalliance/sv-tests (while_loop).
// Upstream's `while` runs over a `string` array in an `initial` block and prints each step; the strings are incidental to the construct and are replaced by ints.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module while_tb (output logic signed [31:0] i_o, output logic signed [31:0] seen);
  int test [4] = '{111, 222, 333, 444};
  always_comb begin
    int i;
    i = 0; seen = 0;
    while(test[i] != 222) begin
      seen = seen + test[i];
      i++;
    end
    i_o = i;
  end
endmodule
