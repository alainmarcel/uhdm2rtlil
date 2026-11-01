// Converted from chipsalliance/sv-tests (statement_labels_seq).
// Upstream labels a sequential block with the PREFIX form (`name: begin`) and chains three blocking assignments inside it, on constants, in an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input logic x, output reg a, output reg b, output reg c);
  always @(*)
    name: begin
      a = x;
      b = a;
      c = b;
    end: name
endmodule
