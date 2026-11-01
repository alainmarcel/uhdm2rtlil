// Converted from chipsalliance/sv-tests (begin-keywords).
// Upstream declares `reg logic;` inside a `begin_keywords "1364-2001"` region -- legal only because `logic` is not a keyword in that standard -- and then never uses it, so nothing confirms the declaration actually took.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`begin_keywords "1364-2001" // use IEEE Std 1364-2001 Verilog keywords
module b_kw(input wire [7:0] x, output wire [7:0] y);
  reg logic; // OK: "logic" is not a keyword in 1364-2001
  // The variable NAMED `logic` is driven and read, so the keyword set really is
  // 1364-2001: under SystemVerilog keywords this is a syntax error, not a signal.
  always @(*)
    logic = x[0];
  assign y = {7'b0, logic};
endmodule
`end_keywords
