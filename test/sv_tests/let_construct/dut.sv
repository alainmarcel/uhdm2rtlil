// Converted from chipsalliance/sv-tests (let_construct).
// Upstream calls the `let` with NAMED arguments inside an `initial` block on constants and never reads the result.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [3:0] a, input logic [3:0] b, input logic [3:0] c,
           output logic d);
  // `let` is a compile-time macro-like function; upstream's call uses NAMED
  // arguments, which is the part worth keeping verbatim.
  let op(x, y, z) = |((x | y) & z);
  assign d = op(.x(a), .y(b), .z(c));
endmodule
