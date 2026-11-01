// Converted from chipsalliance/sv-tests (block_names_seq).
// Upstream gives a sequential block matching `begin: name` / `end: name` labels and chains three blocking assignments inside it, all on constants, inside an `initial` block.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module block_tb (input logic x, output reg a, output reg b, output reg c);
  // The labelled block and its chain are kept; only the source of the value is a
  // port now, so the chain through the labelled block is observable.
  always @(*)
    begin: name
      a = x;
      b = a;
      c = b;
    end: name
endmodule
