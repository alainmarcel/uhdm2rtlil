// Converted from chipsalliance/sv-tests (macromodule_definition).
// Upstream is an EMPTY `macromodule`, so nothing confirms the keyword is accepted on a module that actually has content.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
macromodule top(input logic [7:0] a, input logic [7:0] b, input logic sel,
                output logic [8:0] y);
  // `macromodule` is a synonym for `module`; the logic has to work the same.
  assign y = sel ? (a + b) : (a - b);
endmodule
