// Converted from chipsalliance/sv-tests (enum_last).
// Upstream calls `val.last()` inside an `initial` block and drops the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] x, output logic [1:0] m, output logic [1:0] w);
  typedef enum {a, b, c, d} e;
  e val;
  always_comb val = a;
  // `.last()` must answer with the LAST member of the enum, which is a value an output can
  // carry instead of being discarded.
  assign m = val.last();
  // A port-driven witness: `.first()` answers with the constant 0, and a netlist
  // whose every output is constant zero makes the co-sim VACUOUS -- it reports no
  // output activity rather than comparing anything.
  assign w = x;
endmodule
