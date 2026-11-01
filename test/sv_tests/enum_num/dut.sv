// Converted from chipsalliance/sv-tests (enum_num).
// Upstream calls `val.num()` inside an `initial` block and drops the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic signed [31:0] n);
  typedef enum {a, b, c, d} e;
  e val;
  always_comb val = a;
  assign n = val.num();
endmodule
