// Converted from chipsalliance/sv-tests (copy).
// Upstream writes one element of a packed 2-D array inside an `initial` block, copies it to an element of another array and prints both, so synthesis sees neither.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input bit [3:0] [7:0] x, output bit [3:0] [7:0] a1_o,
           output bit [3:0] [7:0] b2_o);
  bit [3:0] [7:0] arr_a [1:10];
  bit [3:0] [7:0] arr_b [1:10];
  // The whole 32-bit packed element has to survive both the write and the
  // element-to-element copy: upstream's value is 32'hdeadbeef.
  always_comb begin
    arr_a[1] = x;
    arr_b[2] = arr_a[1];
  end
  assign a1_o = arr_a[1];
  assign b2_o = arr_b[2];
endmodule
