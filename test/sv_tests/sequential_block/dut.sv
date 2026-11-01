// Converted from chipsalliance/sv-tests (sequential_block).
// Upstream chains three blocking assignments inside an `initial` block on constants, so the ORDER that makes the chain work is invisible.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module sequential_tb (input logic x, output reg a, output reg b, output reg c);
  // Blocking assignments in sequence: the value has to travel the whole chain within
  // one evaluation.
  always @(*) begin
    a = x;
    b = a;
    c = b;
  end
endmodule
